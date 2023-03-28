import {HubMenuButton} from './hubMenuButton.js'
import {useHookstate} from '../hookstate.js'
import {appsMenu} from './hubState.js'
import {selectActiveAppItem, closeApp, getAppName, getLayoutPos, addToHlayout, addToVlayout, removeFromLayout, renderActiveApp} from './api.js'

const Button = primereact.Button;
const Menubar = primereact.Menubar;
const Splitter = primereact.Splitter;
const SplitterPanel = primereact.SplitterPanel;

const setPanelStyle = (appId, activeId) => {
    return {
        minWidth: '100%',
        minHeight: '100%',
        border: appId == activeId ? '0.5px solid var(--primary-color)' : '0px'
    }
}

const HlayoutTemplate = (props) => {
    return (
        <Splitter stateKey="hLayout" stateStorage="local">
            <SplitterPanel minSize={20}>
                <div
                    tabindex="1"
                    style={setPanelStyle(props.leftId, props.active)}
                    onFocus={() => props.leftId == props.active ? null : selectActiveAppItem(props.leftId)}
                >
                    {props.left()}
                </div>
            </SplitterPanel>
            <SplitterPanel minSize={20}>
                <div
                    tabindex="2"
                    style={setPanelStyle(props.rightId, props.active)}
                    onFocus={() => props.rightId == props.active ? null : selectActiveAppItem(props.rightId)}
                >
                    {props.right()}
                </div>
            </SplitterPanel>
        </Splitter>
    )
}

const VlayoutTemplate = (props) => {
    return (
        <Splitter
            layout="vertical"
            stateKey="vLayout"
            stateStorage="local"
            style={{height: window.innerHeight - 55}}
        >
            <SplitterPanel minSize={20} size={50}>
                <div
                    tabindex="3"
                    style={setPanelStyle(props.topId, props.active)}
                    onFocus={() => props.topId == props.active ? null : selectActiveAppItem(props.topId)}
                >
                    {props.top()}
                </div>
            </SplitterPanel>
            <SplitterPanel minSize={20} size={50}>
                <div
                    tabindex="4"
                    style={setPanelStyle(props.bottomId, props.active)}
                    onFocus={() => props.bottomId == props.active ? null : selectActiveAppItem(props.bottomId)}
                >
                    {props.bottom()}
                </div>
            </SplitterPanel>
        </Splitter>
    )
}

const hLayoutActionCb = (id, layout) => {
    if (layout == false) {
        addToHlayout(id);
    } else {
        removeFromLayout(id);
        selectActiveAppItem(id);
    }
}

const vLayoutActionCb = (id, layout) => {
    if (layout == false) {
        addToVlayout(id);
    } else {
        removeFromLayout(id);
        selectActiveAppItem(id);
    }
}

const SystemAppMenu = (props) => {
    const id = Number(props.id);

    if (id && id < 0) {
        return null
    }

    const [layout] = getLayoutPos(id);

    return (
        <div className="flex align-items-center">
            <Button
                icon="bp bp-cross"
                className="mr-1 p-button-danger p-button-outlined"
                onClick={() => closeApp(id)}
            />
            <Button
                icon={layout == 'hLayout' ? 'bp bp-remove-column-right' : 'bp bp-add-column-right'}
                className="mr-1 p-button-info p-button-outlined"
                onClick={() => hLayoutActionCb(id, layout)}
            />
            <Button
                icon={layout == 'vLayout' ? 'bp bp-remove-row-bottom': 'bp bp-add-row-bottom'}
                className="mr-6 p-button-info p-button-outlined"
                onClick={() => vLayoutActionCb(id, layout)}
            />
                <strong className="mr-6 ">
                    {getAppName(id)}
                </strong>
        </div>
    )
}

const HubAppsContainer = (props) => {
    const activeAppItemState = useHookstate(props.activeAppItemState);

    return (
        <div style={{width: '100%'}}>
            <div
                className="flex align-items-center"
                style={{position: 'fixed', width: '100%', zIndex: 999}}
            >
                <div className="ml-3 mr-6">
                    <HubMenuButton sidebarVisibility={props.sidebarVisibility}/>
                </div>
                <Menubar
                    style={{width: '100%'}}
                    model={appsMenu.get(activeAppItemState.get())}
                    start={<SystemAppMenu id={activeAppItemState.get()}/>}
                />
            </div>
            <div id="hub-app-container" style={{marginTop: '65px'}}>
                    {renderActiveApp(activeAppItemState.get(), HlayoutTemplate, VlayoutTemplate)}
            </div>
        </div>
    )
}

export {
    HubAppsContainer
}