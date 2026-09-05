import Vue from 'vue'
import VueRouter from 'vue-router'
import MainLayout from '@/layouts/MainLayout.vue'

Vue.use(VueRouter)

const routes = [
  {
    path: '/',
    name: 'welcome',
    component: function () {
      return import('../views/login.vue')
    }
  },
  {
    path: '/login',
    name: 'login',
    component: function () {
      return import('../views/login.vue')
    }
  },
  {
    path: '/register',
    name: 'Register',
    component: function () {
      return import('../views/register.vue')
    }
  },
  {
    path: '/retrieve-password',
    name: 'RetrievePassword',
    component: function () {
      return import('../views/retrievePassword.vue')
    }
  },
  {
    path: '/home',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'home',
        component: function () {
          return import('../views/home.vue')
        },
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/role-config',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'RoleConfig',
        component: function () {
          return import('../views/roleConfig.vue')
        },
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/voice-print',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'VoicePrint',
        component: function () {
          return import('../views/VoicePrint.vue')
        },
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/device-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'DeviceManagement',
        component: function () {
          return import('../views/DeviceManagement.vue')
        },
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/user-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'UserManagement',
        component: function () {
          return import('../views/UserManagement.vue')
        },
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/model-config',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'ModelConfig',
        component: function () {
          return import('../views/ModelConfig.vue')
        },
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/params-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'ParamsManagement',
        component: function () {
          return import('../views/ParamsManagement.vue')
        },
        meta: { requiresAuth: true, title: '参数管理' }
      }
    ]
  },
  {
    path: '/knowledge-base-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'KnowledgeBaseManagement',
        component: function () {
          return import('../views/KnowledgeBaseManagement.vue')
        },
        meta: { requiresAuth: true, title: '知识库管理' }
      }
    ]
  },
  {
    path: '/server-side-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'ServerSideManager',
        component: function () {
          return import('../views/ServerSideManager.vue')
        },
        meta: { requiresAuth: true, title: '服务端管理' }
      }
    ]
  },
  {
    path: '/ota-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'OtaManagement',
        component: function () {
          return import('../views/OtaManagement.vue')
        },
        meta: { requiresAuth: true, title: 'OTA管理' }
      }
    ]
  },
  {
    path: '/voice-resource-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'VoiceResourceManagement',
        component: function () {
          return import('../views/VoiceResourceManagement.vue')
        },
        meta: { requiresAuth: true, title: '音色资源开通' }
      }
    ]
  },
  {
    path: '/voice-clone-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'VoiceCloneManagement',
        component: function () {
          return import('../views/VoiceCloneManagement.vue')
        },
        meta: { requiresAuth: true, title: '音色克隆管理' }
      }
    ]
  },
  {
    path: '/dict-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'DictManagement',
        component: function () {
          return import('../views/DictManagement.vue')
        },
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/provider-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'ProviderManagement',
        component: function () {
          return import('../views/ProviderManagement.vue')
        },
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/agent-template-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'AgentTemplateManagement',
        component: function () {
          return import('../views/AgentTemplateManagement.vue')
        },
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/template-quick-config',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'TemplateQuickConfig',
        component: function () {
          return import('../views/TemplateQuickConfig.vue')
        },
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/feature-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'FeatureManagement',
        component: function () {
          return import('../views/FeatureManagement.vue')
        },
        meta: { requiresAuth: true, title: '功能配置' }
      }
    ]
  },
  {
    path: '/replacement-word-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'ReplacementWordManagement',
        component: function () {
          return import('../views/ReplacementWordManagement.vue')
        },
        meta: { requiresAuth: true, title: '替换词管理' }
      }
    ]
  },
  {
    path: '/address-book-management',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'AddressBookManagement',
        component: function () {
          return import('../views/AddressBookManagement.vue')
        },
        meta: { requiresAuth: true, title: '通讯录管理' }
      }
    ]
  }
]

const router = new VueRouter({
  base: process.env.VUE_APP_PUBLIC_PATH || '/',
  routes
})

// 全局处理重复导航，改为刷新页面
const originalPush = VueRouter.prototype.push
VueRouter.prototype.push = function push(location) {
  return originalPush.call(this, location).catch(err => {
    if (err.name === 'NavigationDuplicated') {
      // 如果是重复导航，刷新页面
      window.location.reload()
    } else {
      // 其他错误正常抛出
      throw err
    }
  })
}

// 路由守卫：基于 meta.requiresAuth 判断是否需要登录
router.beforeEach((to, from, next) => {
  const requiresAuth = to.matched.some(record => record.meta && record.meta.requiresAuth)
  if (requiresAuth) {
    const token = localStorage.getItem('token')
    if (!token) {
      next({ name: 'login', query: { redirect: to.fullPath } })
      return
    }
  }
  next()
})

export default router
