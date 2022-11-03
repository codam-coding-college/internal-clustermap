import autobind from 'class-autobind';
import PropTypes from 'prop-types';
import React from 'react';

class ElmWrapper extends React.Component {
  constructor(props) {
    super(props);
    autobind(this);
  }

  componentDidMount() {
    const app = this.props.src.embed(this.node, this.props.flags);

    if (this.props.ports) { this.props.ports(app.ports); }
  }

  shouldComponentUpdate() {
    return false;
  }

  storeNode(node) {
    this.node = node;
  }

  render() {
    return <div ref={this.storeNode} />;
  }
}

ElmWrapper.propTypes = {
  flags: PropTypes.object,
  ports: PropTypes.func,
  src: PropTypes.object.isRequired,
};

export default ElmWrapper;
