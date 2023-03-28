import { themeSwitcherState } from './themeSwitcherState.js';

const getThemes = async () => {
  let req = new nef.serverRequest(nef.scontrollerUrl);
  req.request = {
    req: 'theme_switcher.theme_switcher',
    args: {
      meth: 'get_themes',
      token: nef.getToken()
    }
  };
  let res = await req.send();

  if (!res.jsonData) {
    console.error(`App request "${req.request.req}" filed! No jsonData in response.`);
  }

  return res.jsonData;
};

const setTheme = scheme => {
  scheme = scheme == 'dark' ? 'dark' : 'light';
  const themeURL = themeSwitcherState[scheme].get();
  themeSwitcherState.scheme.set(scheme);
  let linkElem = document.getElementById('theme-link');
  linkElem.href = themeURL;
  localStorage.setItem('colorScheme', scheme);
};

const switchTheme = () => {
  const scheme = themeSwitcherState.scheme.get();

  if (scheme == 'dark') {
    setTheme('light');
    themeSwitcherState.icon.set(themeSwitcherState.darkIcon.get());
  }

  if (scheme == 'light') {
    setTheme('dark');
    themeSwitcherState.icon.set(themeSwitcherState.lightIcon.get());
  }
}; // Example:
// const initState = {
//     classNames: classNames,
//     light: themes.light,
//     dark: themes.dark,
//     scheme: defaultScheme,
//     lightIcon: lightIcon,
//     darkIcon: darkIcon,
//     icon: defaultScheme == 'dark' ? lightIcon : darkIcon
// }


const initThemeSwitcherState = initState => {
  themeSwitcherState.merge(initState);
};

export { getThemes, setTheme, switchTheme, initThemeSwitcherState };
