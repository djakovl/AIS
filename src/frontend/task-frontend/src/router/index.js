import { createRouter, createWebHistory } from 'vue-router'
import TaskListView from '@/views/TaskListView.vue'
import TaskDetailView from '@/views/TaskDetailView.vue'

const routes = [
  {
    path: '/',
    name: 'TaskList',
    component: TaskListView
  },
  {
    path: '/tasks/:id',
    name: 'TaskDetail',
    component: TaskDetailView
  }
]

const router = createRouter({
  history: createWebHistory('/tasks-app/'),
  routes
})

export default router