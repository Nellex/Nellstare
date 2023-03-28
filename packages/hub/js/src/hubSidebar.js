import {useHookstate} from '../hookstate.js'
import {getSidebarMenuData, makeMenu, logout} from './api.js'
import {activeAppItemTemplate, ActiveAppsList} from './activeAppsList.js'
const {useState, useEffect} = React;

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
}

let themeSwitcherRes = await themeSwitcherReq.send();

if (!themeSwitcherRes.url) {
    console.error(`App request "${themeSwitcherReq.request.req}" filed! No url in response.`);
}

const {ThemeSwitcherButton, getThemes, initThemeSwitcherState} = await import(themeSwitcherRes.url);

const themes = await getThemes();

const colorScheme = localStorage.getItem('colorScheme') == 'dark' ? 'dark' : 'light';
let themeSwitcherInitState = {
    classNames: 'p-button-outlined p-button-secondary',
    light: themes.light,
    dark: themes.dark,
    scheme: colorScheme,
    lightIcon: 'bp bp-flash',
    darkIcon: 'bp bp-moon',
};
colorScheme == 'dark' ? themeSwitcherInitState.icon = themeSwitcherInitState.lightIcon : themeSwitcherInitState.icon = themeSwitcherInitState.darkIcon;

initThemeSwitcherState(themeSwitcherInitState);

const HubSidebar = (props) => {
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
    }

    if (sidebarVisibility.get() === false) {
        return null
    }

    return (
        <div
            className="card mr-4 p-2 flex flex-column align-items-center shadow-2"
            style={{minWidth: '250px', height: '100vh'}}
        >
            <div
                className="flex justify-content-end"
                style={{width: '100%'}}
            >
                <Button
                    className="p-button-outlined p-button-rounded mr-2" icon="bp bp-cross"
                    onClick={() => showMenuButton()}
                />
            </div>
            <Avatar icon="pi pi-user" className="m-4" size="xlarge" />
            <b className="mb-4">{userName.get()}</b>
            <div className="formgroup-inline">
                <div className="field">
                    <ThemeSwitcherButton/>
                </div>
                <div className="field">
                    <Button className="p-button-outlined p-button-secondary" icon="bp bp-cog" />
                </div>
                <div className="field">
                    <Button
                        className="p-button-outlined p-button-secondary" icon="bp bp-log-out" label="Exit"
                        onClick={()=> logout()}
                    />
                </div>
            </div>
            <Divider align="center">
                <b>Активные приложения</b>
            </Divider>
            <ActiveAppsList
                activeAppsState={activeAppsState}
                activeAppItemState={activeAppItemState}
                itemTemplate={activeAppItemTemplate}
            />
            <Divider align="center">
                <b>Все приложения</b>
            </Divider>
            <PanelMenu model={sidebarMenu} style={{ width: '100%' }} />
        </div>
    )
}

export {
    HubSidebar
}