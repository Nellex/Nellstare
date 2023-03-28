import {useHookstate} from '../hookstate.js'
import {selectActiveAppItem} from './api.js'
const ListBox = primereact.ListBox;

const activeAppItemTemplate = (option) => {
    return (
        <div>
            <i className={option.activeIcon}></i>
            <i className={`${option.splitIcon} ml-2`}></i>
            <span className="ml-2">
                {option.name}
            </span>
        </div>
    )
}

const ActiveAppsList = (props) => {
    const activeAppsState = useHookstate(props.activeAppsState);
    const activeAppItemState = useHookstate(props.activeAppItemState);

    return (
        <ListBox
            value={activeAppItemState.get()}
            options={activeAppsState.get()}
            onChange={(e) => selectActiveAppItem(e.value)}
            optionLabel="name"
            optionValue="id"
            itemTemplate={props.itemTemplate}
            style={{width: '100%'}}
            metaKeySelection={false}
        />
    )
}

export {
    activeAppItemTemplate,
    ActiveAppsList
}