import { usersToolState } from './usersToolState.js';
const authReq = (config = {}) => {
  let req = new nef.serverRequest(nef.scontrollerUrl);
  req.request = {
    req: 'auth.auth',
    args: {
      token: nef.getToken(),
      ...config
    }
  };
  return req.send();
};

// groups

const openGroupPropertiesView = async (mode = 'create', groupId = 0, groupName = '', groupDescription = '') => {
  if (mode == 'create') {
    await prepareGroupPolicies();
    usersToolState.groupProperties.title.set('Add new group');
    usersToolState.groupProperties.operationMode.set('create');
    usersToolState.groupProperties.actionLabel.set('Create');
  }
  if (mode == 'update') {
    await getGroupPolicies(groupName);
    usersToolState.groupProperties.title.set(`Group ${groupName} properties`);
    usersToolState.groupProperties.operationMode.set('update');
    usersToolState.groupProperties.actionLabel.set('Update');
    usersToolState.groupProperties.prevGroupName.set(groupName);
    usersToolState.groupProperties.prevGroupDescription.set(groupDescription);
    usersToolState.groupProperties.groupName.set(groupName);
    usersToolState.groupProperties.groupDescription.set(groupDescription);
  }
  usersToolState.groupProperties.visible.set(true);
};
const resetGroupPropertiesForm = () => {
  usersToolState.groupProperties.groupName.set('');
  usersToolState.groupProperties.groupDescription.set('');
  usersToolState.groupProperties.allReadPolicy.set(null);
  usersToolState.groupProperties.allWritePolicy.set(null);
};
const closeGroupPropertiesView = () => {
  usersToolState.groupProperties.visible.set(false);
  resetGroupPropertiesForm();
};
const getGroupsViewMessage = () => {
  usersToolState.hasMessage.set(false);
  return {
    severity: usersToolState.messageSeverity.get(),
    detail: usersToolState.message.get(),
    life: 5000
  };
};
const setGroupsViewMessage = (message, severity) => {
  usersToolState.messageSeverity.set(severity);
  usersToolState.message.set(message);
  usersToolState.hasMessage.set(true);
};
const getGroupPropertiesViewMessage = () => {
  usersToolState.groupProperties.hasMessage.set(false);
  return {
    severity: usersToolState.groupProperties.messageSeverity.get(),
    detail: usersToolState.groupProperties.message.get(),
    life: 5000
  };
};
const setGroupPropertiesViewMessage = (message, severity) => {
  usersToolState.groupProperties.messageSeverity.set(severity);
  usersToolState.groupProperties.message.set(message);
  usersToolState.groupProperties.visible.get() == true ? usersToolState.groupProperties.hasMessage.set(true) : usersToolState.groupProperties.hasMessage.set(false);
};
const getGroups = async () => {
  let res = await authReq({
    meth: 'get_grps'
  });
  if (res.raw) {
    usersToolState.groupsList.set([]);
    console.error(`getGroups: ${res.raw}`);
    return false;
  }
  usersToolState.groupsList.set(res.jsonData);
  return true;
};
const getUnits = async () => {
  let res = await authReq({
    meth: 'get_units'
  });
  if (res.raw) {
    usersToolState.unitsList.set([]);
    console.error(`getUnits: ${res.raw}`);
    return false;
  }
  usersToolState.unitsList.set(res.jsonData);
  return true;
};
const prepareGroupPolicies = async () => {
  let unitsRes = await getUnits();
  if (unitsRes == false) {
    usersToolState.groupProperties.groupPolicies.set([]);
    usersToolState.groupProperties.groupPoliciesMap.set([]);
    return false;
  }
  let units = usersToolState.unitsList.get();
  let groupPolicies = [];
  let groupPoliciesMap = {};
  for (let i = 0; i < units.length; i++) {
    groupPolicies.push({
      id: units[i]['id'],
      unit_name: units[i]['unit_name'],
      r_p: false,
      w_p: false
    });
    groupPoliciesMap[units[i]['id']] = groupPolicies.length - 1;
  }
  usersToolState.groupProperties.groupPolicies.set(groupPolicies);
  usersToolState.groupProperties.groupPoliciesMap.set(groupPoliciesMap);
  return true;
};
const getGroupPolicies = async groupName => {
  await prepareGroupPolicies();
  let res = await authReq({
    meth: 'get_grp_policies',
    grp: groupName
  });
  if (res.raw) {
    console.error(`getGroupPolicies: ${res.raw}`);
    return false;
  }
  let groupPolicies = usersToolState.groupProperties.groupPolicies;
  let groupPoliciesMap = usersToolState.groupProperties.groupPoliciesMap;
  for (let i = 0; i < res.jsonData.length; i++) {
    let row = res.jsonData[i];
    const unitName = groupPolicies[groupPoliciesMap[row.unit_id].value]['unit_name'].get();
    groupPolicies.merge(() => ({
      [groupPoliciesMap[row.unit_id].value]: {
        id: row.unit_id,
        unit_name: unitName,
        r_p: row.r_p == 't' ? true : false,
        w_p: row.w_p == 't' ? true : false
      }
    }));
  }
  return true;
};
const sendUpdatePolicyReq = async (groupName, unitName, r_p, w_p) => {
  let res = await authReq({
    meth: 'update_policy',
    grp: groupName,
    unit: unitName,
    r_p: r_p,
    w_p: w_p
  });
  return res;
};
const sendAddPolicyReq = async (groupName, unitName, r_p, w_p) => {
  let res = await authReq({
    meth: 'add_policy',
    grp: groupName,
    unit: unitName,
    r_p: r_p,
    w_p: w_p
  });
  return res;
};
const sendAddGroupReq = async (groupName, description) => {
  let res = await authReq({
    meth: 'add_grp',
    grp: groupName,
    description: description
  });
  return res;
};
const sendRenameGroupReq = async (groupName, newGroupName, description) => {
  let res = await authReq({
    meth: 'rename_grp',
    grp: groupName,
    new_grp: newGroupName,
    description: description
  });
  return res;
};
const sendDeleteGroupReq = async groupName => {
  if (groupName == 'admin') {
    // нельзя удалять админскую группу
    return {
      raw: false
    };
  }
  let res = await authReq({
    meth: 'del_grp',
    grp: groupName
  });
  return res;
};
const addPolicies = async groupName => {
  let groupPolicies = usersToolState.groupProperties.groupPolicies;
  let errors = 0;
  for (let i = 0; i < groupPolicies.keys.length; i++) {
    let row = groupPolicies[i].get();
    let addPolicyRes = await sendAddPolicyReq(groupName, row.unit_name, row.r_p, row.w_p);
    if (addPolicyRes.raw == false) {
      errors++;
      setGroupPropertiesViewMessage(`Error when add policy for group '${groupName}' and unit '${row.unit_name}', see sql log!`, 'error');
    }
  }
  if (errors > 0) {
    return false;
  }
  return true;
};
const updatePolicies = async groupName => {
  let groupPolicies = usersToolState.groupProperties.groupPolicies;
  let errors = 0;
  for (let i = 0; i < groupPolicies.keys.length; i++) {
    let row = groupPolicies[i].get();
    let addPolicyRes = {};
    let updatePolicyRes = await sendUpdatePolicyReq(groupName, row.unit_name, row.r_p, row.w_p);
    if (updatePolicyRes.raw == false) {
      addPolicyRes.raw = false;
      addPolicyRes = await sendAddPolicyReq(groupName, row.unit_name, row.r_p, row.w_p);
    }
    if (addPolicyRes.raw == false) {
      errors++;
      setGroupPropertiesViewMessage(`Error when update policy for group '${groupName}' and unit '${row.unit_name}', see sql log!`, 'error');
    }
  }
  if (errors > 0) {
    return false;
  }
  return true;
};
const deleteGroup = async (groups, selectionCb) => {
  let errors = 0;
  for (let i = 0; i < groups.length; i++) {
    let res = await sendDeleteGroupReq(groups[i]['grp_name']);
    if (res.raw == false) {
      setGroupsViewMessage(`Error when delete group: '${groups[i]['grp_name']}'. Group not exist or read sql error log!`, 'error');
      errors++;
      continue;
    }
    if (res.raw == true) {
      setGroupsViewMessage(`Group '${groups[i]['grp_name']}' deleted!`, 'success');
    }
  }
  selectionCb(null);
  await getGroups();
  if (errors > 0) {
    return false;
  }
  return true;
};
const execGroupPropertiesViewAction = async () => {
  const operationMode = usersToolState.groupProperties.operationMode.get();
  const groupName = usersToolState.groupProperties.groupName.get();
  const groupDescription = usersToolState.groupProperties.groupDescription.get();
  if (operationMode == 'create') {
    let res = await sendAddGroupReq(groupName, groupDescription);
    if (res.encodedData == 'group already exist!') {
      setGroupPropertiesViewMessage(`Group '${groupName}' already exist!`, 'warn');
      return true;
    }
    if (res.raw == false) {
      setGroupPropertiesViewMessage(`Error when adding group: '${groupName}'. Read sql error log!`, 'error');
      return false;
    }
    if (res.raw == true) {
      const addPoliciesRes = await addPolicies(groupName);
      if (addPoliciesRes == false) {
        return false;
      }
      setGroupPropertiesViewMessage(`Group '${groupName}' added!`, 'success');
      resetGroupPropertiesForm();
      await getGroups();
      await prepareGroupPolicies();
    }
    return true;
  }
  if (operationMode == 'update') {
    const prevGroupName = usersToolState.groupProperties.prevGroupName.get();
    const prevGroupDescription = usersToolState.groupProperties.prevGroupDescription.get();
    const errorMessage = `Error when update group: '${prevGroupName}'. Group not exist or read sql error log!`;
    if (prevGroupName !== groupName || prevGroupDescription !== groupDescription) {
      let res = await sendRenameGroupReq(prevGroupName, groupName, groupDescription);
      if (res.raw == false) {
        setGroupPropertiesViewMessage(errorMessage, 'error');
        return false;
      }
    }
    const updatePoliciesRes = await updatePolicies(groupName);
    if (updatePoliciesRes == false) {
      setGroupPropertiesViewMessage(errorMessage, 'error');
      return false;
    }
    await getGroups();
    closeGroupPropertiesView();
    setGroupsViewMessage(`Group ${prevGroupName} -> ${groupName} updated!`, 'success');
    return true;
  }
};

// users
const getUsers = async () => {
  let res = await authReq({
    meth: 'get_usrs'
  });
  if (res.raw) {
    usersToolState.usersList.set([]);
    console.error(`getUsers: ${res.raw}`);
    return false;
  }
  usersToolState.usersList.set(res.jsonData);
  return true;
};
export {
// groups
openGroupPropertiesView, resetGroupPropertiesForm, closeGroupPropertiesView, getGroupsViewMessage, setGroupsViewMessage, getGroupPropertiesViewMessage, setGroupPropertiesViewMessage, getGroups, getUnits, prepareGroupPolicies, getGroupPolicies, sendUpdatePolicyReq, sendAddPolicyReq, sendAddGroupReq, sendRenameGroupReq, sendDeleteGroupReq, addPolicies, updatePolicies, deleteGroup, execGroupPropertiesViewAction,
// users
getUsers };
