import {GroupsView, GroupPropertiesView} from "./groupsView.js";

const Fieldset = primereact.Fieldset;

const App = (props) => {
    return (
        <div className='card flex flex-column'>
            <Fieldset legend='Groups' toggleable={true}>
                <GroupsView
                    groupsList={props.state.groupsList}
                    hasMessage={props.state.hasMessage}
                    searchFilter={props.state.searchFilter}
                />
                <GroupPropertiesView
                    state={props.state.groupProperties}
                />
            </Fieldset>
            <Fieldset legend='Users' toggleable={true} collapsed={true}>
                
            </Fieldset>
        </div>
    )
}

const menu = [];

export {
    App,
    menu
}