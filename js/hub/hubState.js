import { createState } from '../hookstate.js';
const hubState = createState({
  sidebarVisibility: true,
  activeApps: [],
  activeAppsMap: {},
  activeAppItem: -1,
  appsData: {},
  appComponents: {},
  appsLayout: {},
  hLayout: {
    left: -1,
    right: -1
  },
  vLayout: {
    top: -1,
    bottom: -1
  }
});
let appsMenu = new Map();
let appsState = new Map();
export { hubState, appsMenu, appsState };
