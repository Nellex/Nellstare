import { useHookstate } from '../hookstate.js';
import { selectActiveAppItem } from './api.js';
const ListBox = primereact.ListBox;
const activeAppItemTemplate = option => {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("i", {
    className: option.activeIcon
  }), /*#__PURE__*/React.createElement("i", {
    className: `${option.splitIcon} ml-2`
  }), /*#__PURE__*/React.createElement("span", {
    className: "ml-2"
  }, option.name));
};
const ActiveAppsList = props => {
  const activeAppsState = useHookstate(props.activeAppsState);
  const activeAppItemState = useHookstate(props.activeAppItemState);
  return /*#__PURE__*/React.createElement(ListBox, {
    value: activeAppItemState.get(),
    options: activeAppsState.get(),
    onChange: e => selectActiveAppItem(e.value),
    optionLabel: "name",
    optionValue: "id",
    itemTemplate: props.itemTemplate,
    style: {
      width: '100%'
    },
    metaKeySelection: false
  });
};
export { activeAppItemTemplate, ActiveAppsList };
