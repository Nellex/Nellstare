import { HubSidebar } from './hubSidebar.js';
import { HubAppsContainer } from './hubAppsContainer.js';
const Hub = props => {
  return /*#__PURE__*/React.createElement("div", {
    className: "flex"
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(HubSidebar, {
    sidebarVisibility: props.state.sidebarVisibility,
    activeAppsState: props.state.activeApps,
    activeAppItemState: props.state.activeAppItem,
    userName: props.state.userName
  })), /*#__PURE__*/React.createElement(HubAppsContainer, {
    sidebarVisibility: props.state.sidebarVisibility,
    activeAppItemState: props.state.activeAppItem
  }));
};
export { Hub };
