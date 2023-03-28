import { useHookstate } from '../hookstate.js';
import { themeSwitcherState } from './themeSwitcherState.js';
import { switchTheme } from './api.js';
const Button = primereact.Button;

const ThemeSwitcherButton = () => {
  const classNames = useHookstate(themeSwitcherState.classNames);
  const icon = useHookstate(themeSwitcherState.icon);
  return /*#__PURE__*/React.createElement(Button, {
    className: classNames.get(),
    icon: icon.get(),
    onClick: () => switchTheme()
  });
};

export { ThemeSwitcherButton };
