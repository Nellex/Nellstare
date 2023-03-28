import {useHookstate} from '../hookstate.js'
import {
    openGroupPropertiesView,
    closeGroupPropertiesView,
    getGroupsViewMessage,
    getGroupPropertiesViewMessage,
    getGroups,
    deleteGroup,
    execGroupPropertiesViewAction,
} from './api.js';

const {useEffect, useState, useRef} = React;
const InputText = primereact.InputText;
const Button = primereact.Button;
const Checkbox = primereact.Checkbox;
const TriStateCheckbox = primereact.TriStateCheckbox;
const DataTable = primereact.DataTable;
const Column = primereact.Column;
const Toast = primereact.Toast;
const Dialog = primereact.Dialog;

const GroupPropertiesView = (props) => {
    const visible = useHookstate(props.state.visible);
    const title = useHookstate(props.state.title);
    const messageRef = useRef(null);
    const hasMessage = useHookstate(props.state.hasMessage);
    const groupPolicies = useHookstate(props.state.groupPolicies)
    const groupPoliciesMap = useHookstate(props.state.groupPoliciesMap)
    const groupName = useHookstate(props.state.groupName)
    const groupDescription = useHookstate(props.state.groupDescription)
    const allReadPolicy = useHookstate(props.state.allReadPolicy);
    const allWritePolicy = useHookstate(props.state.allWritePolicy);
    const actionLabel = useHookstate(props.state.actionLabel);

    const readPolicyHeader = () =>{
        return (
            <>
                <TriStateCheckbox
                onChange={(e) => {
                    allReadPolicy.set(e.value);

                    if (e.value == true || e.value == null) {
                        for (let i=0; i < (groupPolicies.keys).length; i++) {
                            let row = groupPolicies[i].get();
                            groupPolicies.merge(() => ({[i]: {...row, r_p: e.value || false}}));
                        }
                    }
                }}
                value={allReadPolicy.get()}
                />
                <span className="ml-2">
                    Read
                </span>
            </>
        )
    }

    const writePolicyHeader = () =>{
        return (
            <>
                <TriStateCheckbox
                onChange={(e) => {
                    allWritePolicy.set(e.value);

                    if (e.value == true || e.value == null) {
                        for (let i=0; i < (groupPolicies.keys).length; i++) {
                            let row = groupPolicies[i].get();
                            groupPolicies.merge(() => ({[i]: {...row, w_p: e.value || false}}));
                        }
                    }
                }}
                value={allWritePolicy.get()}
                />
                <span className="ml-2">
                    Write
                </span>
            </>
        )
    }

    const readPolicyBody = (row) => {
        return (
            <Checkbox
                onChange={
                    (e) => {
                        groupPolicies.merge(() => ({[groupPoliciesMap[row.id].value]: {...row, r_p: e.checked}}));

                        if (e.checked == false && allReadPolicy.get() == true) {
                            allReadPolicy.set(false);
                        }
                    }
                }
                checked={row.r_p}
            />
        )
    }

    const writePolicyBody = (row) => {
        return (
            <Checkbox
                onChange={
                    (e) => {
                        groupPolicies.merge(() => ({[groupPoliciesMap[row.id].value]: {...row, w_p: e.checked}}));

                        if (e.checked == false && allWritePolicy.get() == true) {
                            allWritePolicy.set(false);
                        }
                    }
                }
                checked={row.w_p}
            />
        )
    }

    return (
        <Dialog visible={visible.get()} header={title.get()} modal  onHide={closeGroupPropertiesView}>
            <Toast ref={messageRef}/>
            {
                hasMessage.get() == true ? messageRef.current.show(getGroupPropertiesViewMessage()) : null
            }
            <div class="field">
                <label htmlFor="groupname-txt">Group name:</label>
                <InputText
                    className="w-full"
                    id="groupname-txt"
                    type="text"
                    value={groupName.get()}
                    onChange={(e) => groupName.set(e.target.value)}
                />
            </div>
            <div class="field">
                <label htmlFor="description-txt">Description:</label>
                <InputText
                    className="w-full"
                    id="description-txt"
                    type="text"
                    value={groupDescription.get()}
                    onChange={(e) => groupDescription.set(e.target.value)}
                />
            </div>
            <div
                class="field"
                style={{ height: '50vh' }}
            >
                <DataTable
                    style={{width: '30vw'}}
                    value={groupPolicies.get()}
                    header={<p class="text-2xl">Group policies:</p>}
                    dataKey="id"
                    scrollable
                    scrollHeight="flex"
                    selectionMode="single"
                    resizableColumns
                    columnResizeMode="fit"
                    responsiveLayout="scroll"
                >
                    <Column field="id" header="Unit ID" style={ {width:'10%'} }></Column>
                    <Column field="unit_name" header="Unit" style={{width:'50%'}} sortable></Column>
                    <Column field="r_p" header={readPolicyHeader} body={readPolicyBody} style={{width:'20%'}}></Column>
                    <Column field="w_p" header={writePolicyHeader} body={writePolicyBody} style={{width:'20%'}}></Column>
                </DataTable>
            </div>
            <div className="flex col justify-content-end">
                <Button
                    label={actionLabel.get()}
                    className="p-button-lg"
                    onClick={() => execGroupPropertiesViewAction()}
                />
            </div>
        </Dialog>
    )
}

const groupsHeader = (selectionState, selectionCb, searchFilterState) => {
    const searchFilter = useHookstate(searchFilterState);

    return (
        <div className="flex">
            <Button
                type="button"
                icon="bp bp-plus"
                label="New"
                onClick={() => openGroupPropertiesView('create')}
            />
            <Button
                type="button"
                icon="bp bp-trash"
                className="p-button-danger ml-4"
                label="Delete"
                onClick={() => deleteGroup(selectionState, selectionCb)}
                disabled={!selectionState || !selectionState.length}
            />
            <span className="p-input-icon-left ml-4">
                <i className="bp bp-search" />
                <InputText
                    type="search"
                    onInput={(e) => searchFilter.set(e.target.value)}
                    placeholder="Search..."
                />
            </span>
        </div>
    )
};

const GroupsView = (props) => {
    const groupsList = useHookstate(props.groupsList);
    const hasMessage = useHookstate(props.hasMessage);
    const searchFilter = useHookstate(props.searchFilter)
    const messageRef = useRef(null);

    // использовать hookState не получается из-за ошибки primereact
    const [selectedGroups, setSelectedGroups] = useState(null);

    useEffect(() => {
        getGroups();
    }, []);

    const editButton = (row) => {
        return (
            <Button
                className="p-button-lg p-button-text p-button-success"
                icon="bp bp-edit"
                onClick={() => {
                    openGroupPropertiesView('update', row.id, row.grp_name, row.description);
                }}
            />
        )
    }

    return (
        <div
            class="field"
            style={{ height: '50vh' }}
        >
            <Toast ref={messageRef}/>
            {
                hasMessage.get() == true ? messageRef.current.show(getGroupsViewMessage()) : null
            }
            <DataTable
                header={() => groupsHeader(selectedGroups, setSelectedGroups, props.searchFilter)}
                size="small"
                value={groupsList.get()}
                dataKey="id"
                scrollable
                scrollHeight="flex"
                responsiveLayout="scroll"
                selectionMode="checkbox"
                selection={selectedGroups}
                onSelectionChange={e => setSelectedGroups(e.value)}
                globalFilter={searchFilter.get()}
            >
                <Column selectionMode="multiple" headerStyle={{ width: '3em' }}></Column>
                <Column field="id" header="gid" sortable></Column>
                <Column field="grp_name" header="Group" sortable></Column>
                <Column field="description" header="Description"></Column>
                <Column body={editButton}></Column>
            </DataTable>
        </div>
    )
}

export {
    GroupPropertiesView,
    GroupsView,
}