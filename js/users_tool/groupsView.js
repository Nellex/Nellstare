import { useHookstate } from '../hookstate.js';
import { openGroupPropertiesView, closeGroupPropertiesView, getGroupsViewMessage, getGroupPropertiesViewMessage, getGroups, deleteGroup, execGroupPropertiesViewAction } from './api.js';
const {
  useEffect,
  useState,
  useRef
} = React;
const InputText = primereact.InputText;
const Button = primereact.Button;
const Checkbox = primereact.Checkbox;
const TriStateCheckbox = primereact.TriStateCheckbox;
const DataTable = primereact.DataTable;
const Column = primereact.Column;
const Toast = primereact.Toast;
const Dialog = primereact.Dialog;
const GroupPropertiesView = props => {
  const visible = useHookstate(props.state.visible);
  const title = useHookstate(props.state.title);
  const messageRef = useRef(null);
  const hasMessage = useHookstate(props.state.hasMessage);
  const groupPolicies = useHookstate(props.state.groupPolicies);
  const groupPoliciesMap = useHookstate(props.state.groupPoliciesMap);
  const groupName = useHookstate(props.state.groupName);
  const groupDescription = useHookstate(props.state.groupDescription);
  const allReadPolicy = useHookstate(props.state.allReadPolicy);
  const allWritePolicy = useHookstate(props.state.allWritePolicy);
  const actionLabel = useHookstate(props.state.actionLabel);
  const readPolicyHeader = () => {
    return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(TriStateCheckbox, {
      onChange: e => {
        allReadPolicy.set(e.value);
        if (e.value == true || e.value == null) {
          for (let i = 0; i < groupPolicies.keys.length; i++) {
            let row = groupPolicies[i].get();
            groupPolicies.merge(() => ({
              [i]: {
                ...row,
                r_p: e.value || false
              }
            }));
          }
        }
      },
      value: allReadPolicy.get()
    }), /*#__PURE__*/React.createElement("span", {
      className: "ml-2"
    }, "Read"));
  };
  const writePolicyHeader = () => {
    return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(TriStateCheckbox, {
      onChange: e => {
        allWritePolicy.set(e.value);
        if (e.value == true || e.value == null) {
          for (let i = 0; i < groupPolicies.keys.length; i++) {
            let row = groupPolicies[i].get();
            groupPolicies.merge(() => ({
              [i]: {
                ...row,
                w_p: e.value || false
              }
            }));
          }
        }
      },
      value: allWritePolicy.get()
    }), /*#__PURE__*/React.createElement("span", {
      className: "ml-2"
    }, "Write"));
  };
  const readPolicyBody = row => {
    return /*#__PURE__*/React.createElement(Checkbox, {
      onChange: e => {
        groupPolicies.merge(() => ({
          [groupPoliciesMap[row.id].value]: {
            ...row,
            r_p: e.checked
          }
        }));
        if (e.checked == false && allReadPolicy.get() == true) {
          allReadPolicy.set(false);
        }
      },
      checked: row.r_p
    });
  };
  const writePolicyBody = row => {
    return /*#__PURE__*/React.createElement(Checkbox, {
      onChange: e => {
        groupPolicies.merge(() => ({
          [groupPoliciesMap[row.id].value]: {
            ...row,
            w_p: e.checked
          }
        }));
        if (e.checked == false && allWritePolicy.get() == true) {
          allWritePolicy.set(false);
        }
      },
      checked: row.w_p
    });
  };
  return /*#__PURE__*/React.createElement(Dialog, {
    visible: visible.get(),
    header: title.get(),
    modal: true,
    onHide: closeGroupPropertiesView
  }, /*#__PURE__*/React.createElement(Toast, {
    ref: messageRef
  }), hasMessage.get() == true ? messageRef.current.show(getGroupPropertiesViewMessage()) : null, /*#__PURE__*/React.createElement("div", {
    class: "field"
  }, /*#__PURE__*/React.createElement("label", {
    htmlFor: "groupname-txt"
  }, "Group name:"), /*#__PURE__*/React.createElement(InputText, {
    className: "w-full",
    id: "groupname-txt",
    type: "text",
    value: groupName.get(),
    onChange: e => groupName.set(e.target.value)
  })), /*#__PURE__*/React.createElement("div", {
    class: "field"
  }, /*#__PURE__*/React.createElement("label", {
    htmlFor: "description-txt"
  }, "Description:"), /*#__PURE__*/React.createElement(InputText, {
    className: "w-full",
    id: "description-txt",
    type: "text",
    value: groupDescription.get(),
    onChange: e => groupDescription.set(e.target.value)
  })), /*#__PURE__*/React.createElement("div", {
    class: "field",
    style: {
      height: '50vh'
    }
  }, /*#__PURE__*/React.createElement(DataTable, {
    style: {
      width: '30vw'
    },
    value: groupPolicies.get(),
    header: /*#__PURE__*/React.createElement("p", {
      class: "text-2xl"
    }, "Group policies:"),
    dataKey: "id",
    scrollable: true,
    scrollHeight: "flex",
    selectionMode: "single",
    resizableColumns: true,
    columnResizeMode: "fit",
    responsiveLayout: "scroll"
  }, /*#__PURE__*/React.createElement(Column, {
    field: "id",
    header: "Unit ID",
    style: {
      width: '10%'
    }
  }), /*#__PURE__*/React.createElement(Column, {
    field: "unit_name",
    header: "Unit",
    style: {
      width: '50%'
    },
    sortable: true
  }), /*#__PURE__*/React.createElement(Column, {
    field: "r_p",
    header: readPolicyHeader,
    body: readPolicyBody,
    style: {
      width: '20%'
    }
  }), /*#__PURE__*/React.createElement(Column, {
    field: "w_p",
    header: writePolicyHeader,
    body: writePolicyBody,
    style: {
      width: '20%'
    }
  }))), /*#__PURE__*/React.createElement("div", {
    className: "flex col justify-content-end"
  }, /*#__PURE__*/React.createElement(Button, {
    label: actionLabel.get(),
    className: "p-button-lg",
    onClick: () => execGroupPropertiesViewAction()
  })));
};
const groupsHeader = (selectionState, selectionCb, searchFilterState) => {
  const searchFilter = useHookstate(searchFilterState);
  return /*#__PURE__*/React.createElement("div", {
    className: "flex"
  }, /*#__PURE__*/React.createElement(Button, {
    type: "button",
    icon: "bp bp-plus",
    label: "New",
    onClick: () => openGroupPropertiesView('create')
  }), /*#__PURE__*/React.createElement(Button, {
    type: "button",
    icon: "bp bp-trash",
    className: "p-button-danger ml-4",
    label: "Delete",
    onClick: () => deleteGroup(selectionState, selectionCb),
    disabled: !selectionState || !selectionState.length
  }), /*#__PURE__*/React.createElement("span", {
    className: "p-input-icon-left ml-4"
  }, /*#__PURE__*/React.createElement("i", {
    className: "bp bp-search"
  }), /*#__PURE__*/React.createElement(InputText, {
    type: "search",
    onInput: e => searchFilter.set(e.target.value),
    placeholder: "Search..."
  })));
};
const GroupsView = props => {
  const groupsList = useHookstate(props.groupsList);
  const hasMessage = useHookstate(props.hasMessage);
  const searchFilter = useHookstate(props.searchFilter);
  const messageRef = useRef(null);

  // использовать hookState не получается из-за ошибки primereact
  const [selectedGroups, setSelectedGroups] = useState(null);
  useEffect(() => {
    getGroups();
  }, []);
  const editButton = row => {
    return /*#__PURE__*/React.createElement(Button, {
      className: "p-button-lg p-button-text p-button-success",
      icon: "bp bp-edit",
      onClick: () => {
        openGroupPropertiesView('update', row.id, row.grp_name, row.description);
      }
    });
  };
  return /*#__PURE__*/React.createElement("div", {
    class: "field",
    style: {
      height: '50vh'
    }
  }, /*#__PURE__*/React.createElement(Toast, {
    ref: messageRef
  }), hasMessage.get() == true ? messageRef.current.show(getGroupsViewMessage()) : null, /*#__PURE__*/React.createElement(DataTable, {
    header: () => groupsHeader(selectedGroups, setSelectedGroups, props.searchFilter),
    size: "small",
    value: groupsList.get(),
    dataKey: "id",
    scrollable: true,
    scrollHeight: "flex",
    responsiveLayout: "scroll",
    selectionMode: "checkbox",
    selection: selectedGroups,
    onSelectionChange: e => setSelectedGroups(e.value),
    globalFilter: searchFilter.get()
  }, /*#__PURE__*/React.createElement(Column, {
    selectionMode: "multiple",
    headerStyle: {
      width: '3em'
    }
  }), /*#__PURE__*/React.createElement(Column, {
    field: "id",
    header: "gid",
    sortable: true
  }), /*#__PURE__*/React.createElement(Column, {
    field: "grp_name",
    header: "Group",
    sortable: true
  }), /*#__PURE__*/React.createElement(Column, {
    field: "description",
    header: "Description"
  }), /*#__PURE__*/React.createElement(Column, {
    body: editButton
  })));
};
export { GroupPropertiesView, GroupsView };
