import quark from "./quark.js";
import uc from "./uc.js";
import ucTv from "./uc-tv.js";

export default async function website(fastify) {
  fastify.get('/', (req, res) => {
    res.type('text/html').send(`
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <title>首页</title>
      </head>
      <body>
        <div id="app"></div>
        <script>${globalThis.websiteBundle}</script>
      </body>
    </html>
    `)
  })

  fastify.register(quark, {prefix: '/quark'})
  fastify.register(uc, {prefix: '/uc'})
  fastify.register(ucTv, {prefix: '/uc-tv'})
}