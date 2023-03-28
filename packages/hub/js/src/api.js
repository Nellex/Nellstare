import {none} from '../hookstate.js'
import {hubState, appsMenu, appsState} from './hubState.js'

const curtailDbObject = (obj, colName) => {
    let newObj = {};

    for (let i = 0; i < obj.length; i++) {
        if (!obj[i][colName]) {
            continue
        }

        if (!newObj[obj[i][colName]]) {
            newObj[obj[i][colName]] = [];
        }

        newObj[obj[i][colName]].push(obj[i]);
    }
    
    return newObj
}

const getSidebarMenuData = async () => {
    let req = new nef.serverRequest(nef.scontrollerUrl);

    req.request = {
        req: 'hub.hub',
        args: {
            meth: 'get_menu_data',
            token: nef.getToken()
        }
    }

    let res = await req.send();

    if (res.jsonData.error) {
        console.error(res.jsonData.error)

        return {categories: [], items: [], units: []}
    }

    return res.jsonData
}

const makeMenu = (categories, items, units) => {
    if (!Array.isArray(categories)) {
        console.error('categories is not array');

        return []
    }

    if (!Array.isArray(items)) {
        console.error('items is not array');

        return []
    }

    if (!Array.isArray(units)) {
        console.error('units is not array');

        return []
    }

    let menu = [];
    let parents = {};
    let itemsMap = curtailDbObject(items, 'category_id');
    let unitsMap = curtailDbObject(units, 'id');

    for (let i = 0; i < categories.length; i++) {
        let childs = [];

        if (itemsMap[categories[i].id] && itemsMap[categories[i].id].length > 0) {
            for (let j = 0; j < itemsMap[categories[i].id].length; j++) {
                const title = itemsMap[categories[i].id][j].title;
                const icon = itemsMap[categories[i].id][j].icon;
                const unitId = itemsMap[categories[i].id][j].unit_id;
                const unitName = unitsMap[unitId]?.[0]?.unit_name;
                const reqName = `${unitName}.${unitName}`;
                childs.push({
                    label: title,
                    icon: icon,
                    command: () => {runApp(Number(unitId), title, reqName)}
                })
            }
        }

        // if is root category
        if (categories[i].parent.length == 0) {
            menu.push({
                label: categories[i].category,
                icon: categories[i].icon,
                items: childs
            });

            parents[categories[i].category] = menu.length -1;

            continue
        }

        // if (parents[categories[i].parent])
        // данное выражение будет некорректно,
        // поскольку для объекта ключ равный 0 будет сопоставлен с false
        if (categories[i].parent in parents) {
            let idx = parents[categories[i].parent];

            menu[idx].items.push({
                label: categories[i].category,
                icon: categories[i].icon,
                items: childs
            })
        } else {
            menu.push({
                label: categories[i].parent,
                items: [
                    {
                        label: categories[i].category,
                        icon: categories[i].icon,
                        items: childs
                    }
                ]
            })

            parents[categories[i].parent] = menu.length;
        }
    }

    return menu
}

const runApp = async (id, appName, reqName) => {
    const appComponentsState = hubState.appComponents;

    if (id in appComponentsState) {
        selectActiveAppItem(id);

        return true
    }

    let req = new nef.serverRequest(nef.scontrollerUrl);

    req.request = {
        req: reqName,
        args: {
            meth: 'launch',
            token: nef.getToken()
        }
    }

    let res = await req.send();

    if (!res.url) {
        console.error(`App request "${reqName}" filed! No url in response.`);

        return false
    }

    const {App, state, menu} = await import(res.url);
    appsMenu.set(id, menu);
    addAppComponent(id, App, state);
    addActiveAppItem(id, appName);
    selectActiveAppItem(id);
    

    return true
}

const addActiveAppItem = (id, name) => {
    hubState.activeApps.merge([{id: id, name: name, activeIcon: 'bp', splitIcon: 'bp'}]);
    const idx = (hubState.activeApps.keys).length - 1;
    hubState.activeAppsMap.merge({[id]: idx});
}

const delActiveAppItem = (id) => {
    let idx;

    if (id in hubState.activeAppsMap) {
        idx = hubState.activeAppsMap[id].get();
    } else {
        return
    }

    if (idx in hubState.activeApps) {
        hubState.activeApps[idx].set(none);
    } else {
        return
    }

    let newActiveAppsMap = {};

    for (let i=0; i < (hubState.activeApps.keys).length; i++) {
        const id = (hubState.activeApps[i].id).get();
        newActiveAppsMap[id] = i;
    }

    hubState.activeAppsMap.set(newActiveAppsMap);
}

const getAppName = (id) => {
    if (id in hubState.activeAppsMap) {
        const idx = hubState.activeAppsMap[id].get();

        return hubState.activeApps[idx].name.get()
    }

    return ''
}

const getLastId = (id) => {
    let lastId;
    const activeAppsLength = (hubState.activeApps.keys).length;
    const lastIdx = activeAppsLength - 1;

    if (activeAppsLength < 2) {
        return -1
    }

    lastId = Number(hubState.activeApps[lastIdx].id.get());

    if (lastId === id) {
        lastId = Number(hubState.activeApps[lastIdx -1].id.get());
    }

    return lastId
}

const closeApp = (id) => {
    const lastId = getLastId(id);
    lastId === -1 ? hubState.activeAppItem.set(-1) : selectActiveAppItem(lastId);
    removeFromLayout(id);
    delActiveAppItem(id);
    hubState.appsLayout[id].set(none);
    hubState.appComponents[id].set(none);
    appsState.delete(id);
    appsMenu.delete(id);
}

const selectActiveAppItem = (id) => {
    const activeAppsMap = hubState.activeAppsMap.get();
    const prevIdx = hubState.activeAppItem.get() ? Number(hubState.activeAppItem.get()) : undefined;
    const idx = id ? Number(id) : undefined;
    
    if (prevIdx === undefined || idx === undefined) {
        return
    }

    if (prevIdx in activeAppsMap && prevIdx !== idx) {
        (hubState.activeApps[activeAppsMap[prevIdx]].activeIcon).set('bp');
    }

    if (idx in activeAppsMap) {
        (hubState.activeApps[activeAppsMap[idx]].activeIcon).set('bp bp-nest');
        hubState.activeAppItem.set(idx);
    }
}

const markSplittedActiveAppItem = (id) => {
    let idx;

    if (id in hubState.activeAppsMap) {
        idx = hubState.activeAppsMap[id].get();
    } else {
        return
    }

    const appLayout = hubState.appsLayout[id].get();
    let icon = 'bp-applications';

    if (appLayout == 'hLayout') {
        icon = 'bp-drag-handle-vertical';
    }

    if (appLayout == 'vLayout') {
        icon = 'bp-drag-handle-horizontal';
    }

    (hubState.activeApps[idx].splitIcon).set(`bp ${icon}`)
}

const unmarkSplittedActiveAppItem = (id) => {
    let idx;

    if (id in hubState.activeAppsMap) {
        idx =hubState.activeAppsMap[id].get();
    } else {
        return
    }

    (hubState.activeApps[idx].splitIcon).set('bp')
}

const addAppComponent = (id, appComponent, appState) => {
    // create app data state
    appsState.set(id, appState);
    // add app functional component
    hubState.appComponents.merge({[id]: appComponent});
    // add app layout
    hubState.appsLayout.merge({[id]: 'default'});
}

const addToHlayout = (id) => {
    hubState.appsLayout.merge({[id]: 'hLayout'});

    if (Number(hubState.hLayout.left.get()) !== -1) {
        const rightPosId = Number(hubState.hLayout.right.get());
        removeFromLayout(rightPosId);
        hubState.hLayout.right.set(id);
    } else {
        hubState.hLayout.left.set(id);
    }

    markSplittedActiveAppItem(id);
    selectActiveAppItem(id);
}

const addToVlayout = (id) => {
    hubState.appsLayout.merge({[id]: 'vLayout'});

    if (Number(hubState.vLayout.top.get()) !== -1) {
        const bottomPosId = Number(hubState.vLayout.bottom.get());
        removeFromLayout(bottomPosId);
        hubState.vLayout.bottom.set(id);
    } else {
        hubState.vLayout.top.set(id);
    }

    markSplittedActiveAppItem(id);
    selectActiveAppItem(id);
}

const getLayoutPos = (id) => {
    let pos = [false, false]

    if (Number(hubState.hLayout.left.get()) == id) {
        pos[0] = 'hLayout';
        pos[1] = 'left';
    }

    if (Number(hubState.hLayout.right.get()) == id) {
        pos[0] = 'hLayout';
        pos[1] = 'right';
    }

    if (Number(hubState.vLayout.top.get()) == id) {
        pos[0] = 'vLayout';
        pos[1] = 'top';
    }

    if (Number(hubState.vLayout.bottom.get()) == id) {
        pos[0] = 'vLayout';
        pos[1] = 'bottom';
    }

    return pos
}

const removeFromLayout = (id) => {
    if (!(id in hubState.appsLayout)) {
        return false
    }

    if (hubState.appsLayout[id].get() == 'default') {
        return true
    }

    hubState.appsLayout.merge({[id]: 'default'});
    unmarkSplittedActiveAppItem(id);
    const [layout, position] = getLayoutPos(id);

    if (layout == false) {
        console.error(`No layout record for app id ${id}`);

        return false
    }

    if (position == false) {
        console.error(`No layout position for app id ${id}`);

        return false
    }
    
    hubState[layout][position].set(-1);

    return true
}

const renderActiveApp = (id, HlayoutTemplate, VlayoutTemplate) => {
    const appLayout = hubState.appsLayout[id].get();
    
    if (appLayout == 'default') {
        return (
            <div>
                {React.createElement(hubState.appComponents[id].get(), {state: appsState.get(id)})}
            </div>
        )
    }

    if (appLayout == 'hLayout') {
        const leftPosId = Number(hubState.hLayout.left.get());
        const rightPosId = Number(hubState.hLayout.right.get());

        let leftApp = () => null;
        let rightApp = () => null;

        if (leftPosId in hubState.appComponents) {
            leftApp = () => React.createElement(hubState.appComponents[leftPosId].get(), {state: appsState.get(leftPosId)})
        }

        if (rightPosId in hubState.appComponents) {
            rightApp = () => React.createElement(hubState.appComponents[rightPosId].get(), {state: appsState.get(rightPosId)})
        }

        return (
            <HlayoutTemplate left={leftApp} right={rightApp} active={id} leftId={leftPosId} rightId={rightPosId}/>
        )
    }

    if (appLayout == 'vLayout') {
        const topPosId = Number(hubState.vLayout.top.get());
        const bottomPosId = Number(hubState.vLayout.bottom.get());

        let topApp = () => null;
        let bottomApp = () => null;

        if (topPosId in hubState.appComponents) {
            topApp = () => React.createElement(hubState.appComponents[topPosId].get(), {state: appsState.get(topPosId)})
        }

        if (bottomPosId in hubState.appComponents) {
            bottomApp = () => React.createElement(hubState.appComponents[bottomPosId].get(), {state: appsState.get(bottomPosId)})
        }

        return (
            <VlayoutTemplate top={topApp} bottom={bottomApp} active={id} topId={topPosId} bottomId={bottomPosId}/>
        )
    }
    
    return null
}

const logout = async () => {
    let req = new nef.serverRequest(nef.scontrollerUrl);

    req.request = {
        req: 'logout.logout',
        args: {
            meth: 'logout',
            token: nef.getToken()
        }
    }

    let res = await req.send();

    if (res.encodedData == 'logout') {
        localStorage.clear();

        return location.reload()
    }

    console.error(res);
}

export {
    getSidebarMenuData,
    makeMenu,
    runApp,
    addActiveAppItem,
    delActiveAppItem,
    getAppName,
    closeApp,
    selectActiveAppItem,
    markSplittedActiveAppItem,
    unmarkSplittedActiveAppItem,
    addAppComponent,
    addToHlayout,
    addToVlayout,
    getLayoutPos,
    removeFromLayout,
    renderActiveApp,
    logout
}