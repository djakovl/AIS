<template>
  <div id="app">
    <nav class="navbar">
      <div class="nav-brand">📋 Task Manager</div>
    </nav>
    <main>
      <router-view />
    </main>
  </div>
</template>

<script setup>
// App setup
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background: #f5f5f5;
  color: #333;
}

#app {
  min-height: 100vh;
}

.navbar {
  background: #2196f3;
  color: white;
  padding: 1rem 2rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.nav-brand {
  font-size: 1.5rem;
  font-weight: 600;
}

main {
  min-height: calc(100vh - 73px);
}
</style>