/** @jsx React.DOM */

HelloWorld = React.createClass({
  propTypes: {
    name: React.PropTypes.string
  },

  getDefaultProps: function() {
    return {
      name: 'World'
    };
  },

  componentDidMount: function() {
    setTimeout(function() {
      this.setState({ name: "Browser" });
    }.bind(this), 2000);
  },

  getInitialState: function() {
    return {};
  },

  name: function() {
    return this.state.name || this.props.name;
  },

  render: function() {
    return <h1>Hello {this.name()}</h1>;
  }
});
