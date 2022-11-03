import React from "react";
import ElmWrapper from "../utils/elm"
import Elm from "../../public/js/Main.js"

class Clustermap extends React.Component {
  render() {
    const flags = {
      heigth: 1080,
      width: 1920,
      isFirefox: false,
    };
    return <ElmWrapper src={Elm.Main} flags={flags} />
  }
}
export default Clustermap;
