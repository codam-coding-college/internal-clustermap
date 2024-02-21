import type { NextApiRequest, NextApiResponse } from "next";
import Cors from "cors";
import NodeCache from "node-cache";

const imageCache = new NodeCache();
const userPhotosServer = "https://user-photos.codam.nl";

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

  // Get the image from the cache if it exists
  const image = imageCache.get(req.query.login as string);
  if (image) {
    res.send(image as Buffer);
  } else {
    // Fetch the image from the user-photos server if it's not in the cache
    const response = await fetch(`${userPhotosServer}/${req.query.login}/100`);
    const data = await response.arrayBuffer();
    const buffer = Buffer.from(data); // Convert to Node.JS buffer to make Next.js send the raw data back correctly
    if (response.ok) {
      console.log(`Cache miss for ${req.query.login}, fetching image from user-photos.codam.nl...`);
      imageCache.set(req.query.login as string, buffer, 3600); // Cache the image for 1 hour
      res.status(response.status).send(buffer);
    } else {
      console.log(`Failed to fetch image for ${req.query.login} from user-photos.codam.nl`);
      res.status(response.status).send(buffer);
    }
  }
};

export default images;
