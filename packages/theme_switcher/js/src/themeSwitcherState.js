import {createState} from '../hookstate.js'

const themeSwitcherState = createState({
    classNames: 'p-button-outlined p-button-secondary',
    light: '',
    dark: '',
    scheme: 'dark',
    lightIcon: 'bp bp-flash',
    darkIcon: 'bp bp-moon',
    icon: ''
})

export {
    themeSwitcherState
}