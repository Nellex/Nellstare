import { GroupsView, GroupPropertiesView } from "./groupsView.js";
const Fieldset = primereact.Fieldset;
const App = props => {
  return /*#__PURE__*/React.createElement("div", {
    className: "card flex flex-column"
  }, /*#__PURE__*/React.createElement(Fieldset, {
    legend: "Groups",
    toggleable: true
  }, /*#__PURE__*/React.createElement(GroupsView, {
    groupsList: props.state.groupsList,
    hasMessage: props.state.hasMessage,
    searchFilter: props.state.searchFilter
  }), /*#__PURE__*/React.createElement(GroupPropertiesView, {
    state: props.state.groupProperties
  })), /*#__PURE__*/React.createElement(Fieldset, {
    legend: "Users",
    toggleable: true,
    collapsed: true
  }));
};
const menu = [];
export { App, menu };
