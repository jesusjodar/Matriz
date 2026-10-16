import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir:'./browser-tests',fullyParallel:false,
  use:{baseURL:'http://127.0.0.1:5173',headless:true,launchOptions:{args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']}},
  webServer:{command:'npm run dev -- --host 127.0.0.1',url:'http://127.0.0.1:5173',reuseExistingServer:!process.env.CI},
})
