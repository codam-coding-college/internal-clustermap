import type { NextApiRequest, NextApiResponse } from "next";
import Cors from "cors";
import NodeCache from "node-cache";

const imageCache = new NodeCache();

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

const images = async (req: NextApiRequest, res: NextApiResponse) => {
  await runMiddleware(req, res, cors);

  //TODO: add proxy for user-photos.codam.nl to make internal clustermap available externally (once it's behind a login wall)

  res.status(501).json({ error: "Not Implemented" });
};

export default images;
