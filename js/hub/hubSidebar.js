import { useHookstate } from '../hookstate.js';
import { getSidebarMenuData, makeMenu, logout } from './api.js';
import { activeAppItemTemplate, ActiveAppsList } from './activeAppsList.js';
const {
  useState,
  useEffect
} = React;
const PanelMenu = primereact.PanelMenu;
const Avatar = primereact.Avatar;
const Button = primereact.Button;
const Divider = primereact.Divider;
let themeSwitcherReq = new nef.serverRequest(nef.scontrollerUrl);
themeSwitcherReq.request = {
  req: 'theme_switcher.theme_switcher',
  args: {
    meth: 'launch',
    token: nef.getToken()
  }
};
let themeSwitcherRes = await themeSwitcherReq.send();
if (!themeSwitcherRes.url) {
  console.error(`App request "${themeSwitcherReq.request.req}" filed! No url in response.`);
}
const {
  ThemeSwitcherButton,
  getThemes,
  initThemeSwitcherState
} = await import(themeSwitcherRes.url);
const themes = await getThemes();
const colorScheme = localStorage.getItem('colorScheme') == 'dark' ? 'dark' : 'light';
let themeSwitcherInitState = {
  classNames: 'p-button-outlined p-button-secondary',
  light: themes.light,
  dark: themes.dark,
  scheme: colorScheme,
  lightIcon: 'bp bp-flash',
  darkIcon: 'bp bp-moon'
};
colorScheme == 'dark' ? themeSwitcherInitState.icon = themeSwitcherInitState.lightIcon : themeSwitcherInitState.icon = themeSwitcherInitState.darkIcon;
initThemeSwitcherState(themeSwitcherInitState);
const HubSidebar = props => {
  const sidebarVisibility = useHookstate(props.sidebarVisibility);
  const activeAppsState = useHookstate(props.activeAppsState);
  const activeAppItemState = useHookstate(props.activeAppItemState);
  const userName = useHookstate('Иванов Иван');
  const [sidebarMenu, setSidebarMenu] = useState([]);
  useEffect(async () => {
    const menuData = await getSidebarMenuData();
    setSidebarMenu(makeMenu(menuData.categories, menuData.items, menuData.units));
  }, []);
  const showMenuButton = () => {
    sidebarVisibility.set(false);
  };
  if (sidebarVisibility.get() === false) {
    return null;
  }
  return /*#__PURE__*/React.createElement("div", {
    className: "card mr-4 p-2 flex flex-column align-items-center shadow-2",
    style: {
      minWidth: '250px',
      height: '100vh'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "flex justify-content-end",
    style: {
      width: '100%'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    className: "p-button-outlined p-button-rounded mr-2",
    icon: "bp bp-cross",
    onClick: () => showMenuButton()
  })), /*#__PURE__*/React.createElement(Avatar, {
    icon: "pi pi-user",
    className: "m-4",
    size: "xlarge"
  }), /*#__PURE__*/React.createElement("b", {
    className: "mb-4"
  }, userName.get()), /*#__PURE__*/React.createElement("div", {
    className: "formgroup-inline"
  }, /*#__PURE__*/React.createElement("div", {
    className: "field"
  }, /*#__PURE__*/React.createElement(ThemeSwitcherButton, null)), /*#__PURE__*/React.createElement("div", {
    className: "field"
  }, /*#__PURE__*/React.createElement(Button, {
    className: "p-button-outlined p-button-secondary",
    icon: "bp bp-cog"
  })), /*#__PURE__*/React.createElement("div", {
    className: "field"
  }, /*#__PURE__*/React.createElement(Button, {
    className: "p-button-outlined p-button-secondary",
    icon: "bp bp-log-out",
    label: "Exit",
    onClick: () => logout()
  }))), /*#__PURE__*/React.createElement(Divider, {
    align: "center"
  }, /*#__PURE__*/React.createElement("b", null, "\u0410\u043A\u0442\u0438\u0432\u043D\u044B\u0435 \u043F\u0440\u0438\u043B\u043E\u0436\u0435\u043D\u0438\u044F")), /*#__PURE__*/React.createElement(ActiveAppsList, {
    activeAppsState: activeAppsState,
    activeAppItemState: activeAppItemState,
    itemTemplate: activeAppItemTemplate
  }), /*#__PURE__*/React.createElement(Divider, {
    align: "center"
  }, /*#__PURE__*/React.createElement("b", null, "\u0412\u0441\u0435 \u043F\u0440\u0438\u043B\u043E\u0436\u0435\u043D\u0438\u044F")), /*#__PURE__*/React.createElement(PanelMenu, {
    model: sidebarMenu,
    style: {
      width: '100%'
    }
  }));
};
export { HubSidebar };
