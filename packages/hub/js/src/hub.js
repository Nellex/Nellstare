import {HubSidebar} from './hubSidebar.js'
import {HubAppsContainer} from './hubAppsContainer.js'

const Hub = (props) => {
    return (
        <div className="flex">
            <div>
                <HubSidebar
                    sidebarVisibility={props.state.sidebarVisibility}
                    activeAppsState={props.state.activeApps}
                    activeAppItemState={props.state.activeAppItem}
                    userName={props.state.userName}
                />
            </div>
            <HubAppsContainer
                sidebarVisibility={props.state.sidebarVisibility}
                activeAppItemState={props.state.activeAppItem}
            />
        </div>
    )
}

export {
    Hub
}