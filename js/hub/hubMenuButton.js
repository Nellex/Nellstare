import { useHookstate } from '../hookstate.js';
const Button = primereact.Button;
const HubMenuButton = props => {
  const sidebarVisibility = useHookstate(props.sidebarVisibility);
  return !sidebarVisibility.get() === true ? /*#__PURE__*/React.createElement(Button, {
    className: "p-button-icon",
    icon: "bp bp-menu",
    onClick: () => sidebarVisibility.set(true)
  }) : null;
};
export { HubMenuButton };
