<template>
  <div class="filters">
    <div class="filter-tabs">
      <button 
        class="filter-tab"
        :class="{ active: !filters.priority_id }"
        @click="setFilter('priority_id', null)"
      >
        Все {{ totalCount }}
      </button>
      
      <button 
        v-for="(count, priorityId) in priorityCounts" 
        :key="priorityId"
        class="filter-tab"
        :class="{ active: filters.priority_id === priorityId }"
        :style="getPriorityStyle(priorityId)"
        @click="setFilter('priority_id', priorityId)"
      >
        {{ getPriorityName(priorityId) }} {{ count }}
      </button>
    </div>

    <div class="filter-search">
      <input 
        v-model="searchQuery"
        type="text"
        placeholder="Поиск задач..."
        class="search-input"
      />
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import { useTaskStore } from '@/stores/taskStore'

const store = useTaskStore()
const filters = computed(() => store.filters)
const tasks = computed(() => store.tasks)

const totalCount = computed(() => tasks.value.length)

const priorityCounts = computed(() => {
  return tasks.value.reduce((acc, task) => {
    const priorityId = task.priority?.id
    if (priorityId) {
      acc[priorityId] = (acc[priorityId] || 0) + 1
    }
    return acc
  }, {})
})

const searchQuery = ref('')

const getPriorityName = (priorityId) => {
  const task = tasks.value.find(t => t.priority?.id === priorityId)
  return task?.priority?.name?.split(' - ')[1] || priorityId
}

const getPriorityStyle = (priorityId) => {
  const task = tasks.value.find(t => t.priority?.id === priorityId)
  const color = task?.priority?.color || '#ccc'
  return {
    backgroundColor: filters.value.priority_id === priorityId ? color : color + '20',
    color: filters.value.priority_id === priorityId ? 'white' : color,
    borderColor: color
  }
}

const setFilter = (key, value) => {
  store.setFilter(key, value)
  store.fetchTasks()
}

watch(searchQuery, (newValue) => {
  store.setFilter('search', newValue)
  store.fetchTasks()
}, { debounce: 300 })
</script>

<style scoped>
.filters {
  background: white;
  padding: 1rem;
  border-radius: 12px;
  margin-bottom: 1rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.filter-tabs {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.filter-tab {
  padding: 0.5rem 1rem;
  border: 2px solid;
  background: white;
  border-radius: 20px;
  cursor: pointer;
  font-size: 0.9rem;
  font-weight: 500;
  transition: all 0.2s;
}

.filter-tab.active {
  color: white !important;
}

.filter-search {
  width: 100%;
}

.search-input {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-size: 1rem;
  transition: border-color 0.2s;
}

.search-input:focus {
  outline: none;
  border-color: #2196f3;
}
</style>