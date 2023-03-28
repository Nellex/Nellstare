import {createState} from '../hookstate.js'

const usersToolState = createState({
    groupsList: [],
    unitsList: [],
    searchFilter: '',
    hasMessage: false,
    message: "",
    messageSeverity: "success",
    groupProperties: {
        visible: false,
        title: 'New group',
        operationMode: 'create',
        hasMessage: false,
        message: "",
        messageSeverity: "success",
        groupPolicies: [],
        groupPoliciesMap: [],
        groupName: '',
        groupDescription: '',
        prevGroupName: '',
        prevGroupDescription: '',
        allReadPolicy: null,
        allWritePolicy: null,
        actionLabel: 'Create',
    },
});

export {
    usersToolState
}