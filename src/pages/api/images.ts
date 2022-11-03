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

  let images = imageCache.get("images");
  if (images == undefined) {
    const image_secret = process.env.IMAGE_SECRET;
    const new_images = await fetch(`https://intra.codam.nl/api/veryprivateimageendpoint/${image_secret}`)
    if (!new_images.ok) {
        res.status(500).json({ error: "Could not fetch images" });
        return;
    }
    const json = await new_images.json();
    imageCache.set("images", json, 120);
    images = json;
  }
  res.status(200).json(images);
};

export default images;
