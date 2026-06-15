import { mount } from 'svelte'
import './app.css'
import './theme.css'
import { initTheme } from './lib/theme.svelte'
import { initKeys } from './lib/keys'
import App from './App.svelte'

initTheme()
initKeys()

const app = mount(App, {
  target: document.getElementById('app')!,
})

export default app
