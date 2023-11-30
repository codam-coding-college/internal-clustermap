import type { NextApiRequest, NextApiResponse } from "next";
import Cors from "cors";
import NodeCache from "node-cache";
import { PrismaClient as CrsClient } from "../../server/db/crsClient";
import { Workstation } from "../../server/db/crsClient";
import { PrismaClient as ExamClient } from "../../server/db/examClient";

const crsPrisma = new CrsClient();
const examPrisma = new ExamClient();

const locationCache = new NodeCache();

const cors = Cors({
  methods: ['POST', 'GET', 'HEAD'],
})

// Helper method to wait for a middleware to execute before continuing
// And to throw an error when an error happens in a middleware
function runMiddleware(
  req: NextApiRequest,
  res: NextApiResponse,
  fn: Function
) {
  return new Promise((resolve, reject) => {
    fn(req, res, (result: any) => {
      if (result instanceof Error) {
        return reject(result)
      }

      return resolve(result)
    })
  })
}

// Helper function to translate IP addresses into hostnames (for Exam-master V2 or missing hostnames)
function getHostName(ip: string) {
  const ipParts = ip.split(".", 4);
  if (ipParts.length != 4) {
    return undefined;
  }
  const floor = ipParts[1]?.charAt(1);
  return `f${floor}r${ipParts[2]}s${ipParts[3]}`;
}

// Function to fetch hosts that are in exam mode from the exam-rebooter service
// If this fails, it will return an empty array, so the rest of the code can still run and a clustermap still gets generated
async function getHostsInExamMode() {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3000);

    // The URL below is only accessible from allowed IP ranges. Ask Codam IT for access if developing locally and you get a 403 error
    const request = await fetch("https://clusterdata.codam.nl/api/exam_mode_hosts", {
      signal: controller.signal,
    });
    clearTimeout(timeout);
    const response = await request.json();
    if ("error" in response) {
      throw new Error(response["error"]);
    }
    return response["exam_mode_hosts"];
  }
  catch (err) {
    console.log("Failed to fetch hosts in exam mode: " + err);
    return [];
  }
}

// Interface for locations provided in the response JSON
interface ResponseLocation {
  login: string | null;
  hostname: string;
  sessionType: 'normal' | 'exam' | 'dead';
  alive: boolean;
}

async function getCRLocations() {
  const responseLocations : ResponseLocation[] = [];

  // Get locations straight from Maxreport
  const db_locations = await crsPrisma.location.findMany({
    where: {
      end_at: null,
    },
    select: {
      login: true,
      hostname: true,
    }
  });

  // Add Maxreport locations to the response
  for (const location of db_locations) {
    responseLocations.push({
      login: location.login,
      hostname: location.hostname ? location.hostname : 'null',
      sessionType: 'normal',
      alive: true
    });
  }

  return responseLocations;
}

async function getExamLocations() {
  const responseLocations : ResponseLocation[] = [];

  // Get locations from Exam-master V3
  const examdb_sessions = examPrisma.exam_session.findMany({
    where: {
      OR: [
        { state: "wait_choice" },
        { state: "in_progress" }
      ],
    },
    select: {
      user: {
        select: {
          username: true
        },
      },
      last_known_ip: true,
      last_known_hostname: true,
    },
  });

  // Add Exam-master V2 sessions to the response
  for (const session of await examdb_sessions) {
    const hostname = session.last_known_hostname || getHostName(session.last_known_ip);
    if (hostname == undefined || hostname == 'Unknown' || hostname == null || hostname == 'null') {
      continue;
    }
    responseLocations.push({
      login: session.user.username,
      hostname: `${hostname}.codam.nl`,
      sessionType: 'exam',
      alive: true
    });
  }

  return responseLocations;
}

const locations = async (req: NextApiRequest, res: NextApiResponse) => {
  await runMiddleware(req, res, cors);

  const responseJSON : ResponseLocation[] = [];
  let response = locationCache.get("response");

  if (!response) {
    console.log("No response locations in cache, fetching from database");

    // Get locations from Cluster Reporter
    for (const responseLocation of await getCRLocations()) {
      responseJSON.push(responseLocation);
    }
    console.log(`Got ${responseJSON.length} response locations after fetching from Cluster Reporter`);

    // Get locations from Exam-master
    for (const responseLocation of await getExamLocations()) {
      responseJSON.push(responseLocation);
    }
    console.log(`Got ${responseJSON.length} response locations after fetching from Exam-master`);

    // Get host info from Cluster Reporter to mark dead hosts
    const db_workstations = await crsPrisma.workstation.findMany({
      where: {
        alive: false,
        active: true
      },
      select: {
        hostname: true,
        alive: true,
        // active: true
      }
    });

    // Add dead hosts to the response
    deadHostsLoop: for (const workstation of db_workstations as Workstation[]) {
      // First check if the hostname is not already in the response JSON
      for (const workstationLocation of responseJSON) {
        if (workstationLocation.hostname == workstation.hostname) {
          // If it is, modify it
          workstationLocation.alive = workstation.alive ? true : false;
          workstationLocation.sessionType = 'dead';
          console.log(`Marked dead host at ${workstation.hostname} as dead (was already in response locations)`);
          continue deadHostsLoop;
        }
      }

      // If it's not, add it
      responseJSON.push({
        login: null,
        hostname: workstation.hostname ? workstation.hostname : 'null',
        alive: workstation.alive ? true : false,
        sessionType: 'dead'
      });
      console.log(`Pushed dead host at ${workstation.hostname} to response locations`);
    }

    // Get hosts in exam mode from the exam-rebooter service
    const examHosts = await getHostsInExamMode();

    // Modify all hosts in the response that are in exam mode
    for (const responseLocation of responseJSON) {
      if (examHosts.includes(responseLocation.hostname)) {
        responseLocation.sessionType = 'exam';
        console.log(`Marked host at ${responseLocation.hostname} as in exam mode (was already in response locations)`);
      }
    }

    // Add any missing hosts in exam mode to the response
    for (const examHost of examHosts) {
      if (!responseJSON.some((responseLocation) => responseLocation.hostname == examHost)) {
        responseJSON.push({
          login: null,
          hostname: examHost,
          sessionType: 'exam',
          alive: true
        });
        console.log(`Pushed host in exam mode at ${examHost} to response locations`);
      }
    }

    // Store locations in cache
    locationCache.set("response", responseJSON, 5);
    response = responseJSON;
    console.log("Stored response locations in cache");
  }

  res.status(200).json(response);
};

export default locations;
