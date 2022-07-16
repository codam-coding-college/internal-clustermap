import type { NextApiRequest, NextApiResponse } from "next";
import { prisma } from "../../server/db/client";
import Cors from "cors";
import NodeCache from "node-cache";

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
  if (locations == undefined) {
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
  }
  res.status(200).json(locations);
};

export default locations;
