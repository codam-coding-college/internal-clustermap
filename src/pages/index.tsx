import type { NextPage } from "next";
import Head from "next/head";

const Home: NextPage = () => {
  return (
    <>
      <Head>
        <title>Codam Clustermaps</title>
        <link rel="stylesheet" href="css/clustermap.css" />
        <link rel="stylesheet" href="css/bootstrap.min.css" />
        <link rel="icon" type="image/png" sizes="64x64" href="img/favicon-codam.png" />
      </Head>

      <main></main>
      <script src="js/interactive_maps.js"></script>
      <script src="js/port.js"></script>
    </>
  );
};

export default Home;
