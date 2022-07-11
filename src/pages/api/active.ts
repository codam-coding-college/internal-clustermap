import type { NextApiRequest, NextApiResponse } from "next";
import { prisma } from "../../server/db/client";
import Cors from "cors";

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

    const locations = await prisma.location.findMany({
    where: {
        end_at: null,
    },
    select: {
        login: true,
        hostname: true,
    }
  });

  res.status(200).json(locations);
};

export default locations;
