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

// Interface for locations provided in the response JSON
interface ResponseLocation {
  login: string | null;
  hostname: string;
  sessionType: 'normal' | 'exam' | 'dead';
  alive: boolean;
}

async function getMaxreportLocations() {
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

  if (response == undefined) {
    for (const responseLocation of await getMaxreportLocations()) {
      responseJSON.push(responseLocation);
    }
    for (const responseLocation of await getExamLocations()) {
      responseJSON.push(responseLocation);
    }

    // Get host info from Maxreport to mark dead hosts
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

      // Store locations in cache
      locationCache.set("response", responseJSON, 5);
      response = responseJSON;
    }
  }

  res.status(200).json(response);
};

export default locations;
