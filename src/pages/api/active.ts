import type { NextApiRequest, NextApiResponse } from "next";
import { prisma } from "../../server/db/client";
import Cors from "cors";
import NodeCache from "node-cache";
import { Host, Location } from "@prisma/client";

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

const locations = async (req: NextApiRequest, res: NextApiResponse) => {
  await runMiddleware(req, res, cors);

  let locations = locationCache.get("locations");
  let hosts = locationCache.get("hosts");
  if (locations == undefined || hosts == undefined) {
    const db_locations = await prisma.location.findMany({
      where: {
        end_at: null,
      },
      select: {
        login: true,
        hostname: true,
      }
    });
    locationCache.set("locations", db_locations, 5);
    locations = db_locations;

    const db_hosts = await prisma.host.findMany({
      where: {
        deleted_at: null,
        alive: false
      },
      select: {
        hostname: true,
        alive: true,
        // checkable: true
      }
    });
    locationCache.set("hosts", db_hosts, 5);
    hosts = db_hosts;
  }

  const responseJSON = [];

  // Add locations to the response
  for (const location of locations as Location[]) {
    responseJSON.push({
      login: location.login,
      hostname: location.hostname,
      alive: true
    });
  }

  // Add dead hosts to the response
  deadHostsLoop: for (const host of hosts as Host[]) {
    // First check if the hostname is not already in the response JSON
    for (const hostLocation of responseJSON) {
      if (hostLocation.hostname == host.hostname) {
        // If it is, modify it
        hostLocation.alive = host.alive;
        continue deadHostsLoop;
      }
    }

    // If it's not, add it
    responseJSON.push({
      login: null,
      hostname: host.hostname,
      alive: host.alive,
    });
  }

  res.status(200).json(responseJSON);
};

export default locations;
