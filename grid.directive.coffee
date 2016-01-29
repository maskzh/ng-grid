angular.module 'jkbs'
  .directive 'grid', ->
    GridController = (Util, $sce, $timeout, toastr) ->
      'ngInject'
      vm = this
      # 数据和分页
      vm.list = []
      vm.parsedList = []
      vm.currentPage = 1
      vm.totalItems = 0

      # 状态字段
      vm.isNoData = false
      vm.isLoading = true
      vm.isError = false

      # 其它字段
      vm.currentListApi = '' # 当前请求的地址
      vm.currentQuery = ''
      vm.available = null
      vm.ths = [] # 表头的标题们
      vm.selectedItems = [] # 被选中的条目

      status =
        error: () ->
          vm.isNoData = false
          vm.isLoading = false
          vm.isError = true
        loading: () ->
          vm.isLoading = true
          vm.isNoData = false
          vm.isError = false
        noData: () ->
          vm.isNoData = true
          vm.isLoading = false
          vm.isError = false
        hide: () ->
          vm.isNoData = false
          vm.isLoading = false
          vm.isError = false

      # 请求发送的数据
      sendData = {page: 1, 'per-page': 10}
      resetSendData = ->
        if vm.tabs
          for tabs in vm.tabs
            tabs[0].active = true
        sendData = {page: 1, 'per-page': 10}

      # 根据提供的 表格table 处理数据
      handleList = (items, table) ->
        result = []
        for item in items
          # 循环 items
          tmp = []
          tmp.id = item.id
          for map in table
            # 根据 table 处理每个 item
            key = map.field
            value = if key? then item[key] else ''
            # 如果有 render 方法
            render = map.render
            if render?
              value = render(value, item)
            # 将每个字段的处理结果推入 tmp
            tmp.push value
          # 将每个 item 的处理结果推入 result
          result.push tmp
        # 最后返回 result
        result

      # 发起请求获取数据，并处理生成传递到模板中的字段
      getList = (url, data) ->
        # reset
        vm.selectedItems = []
        vm.updateCheckedAll()
        status.loading()

        Util.get url, data
          .then (res)->
            if !res.data.items or res.data.items.length is 0
              vm.list = []
              vm.parsedList = []
              status.noData()
              return

            # 赋值
            vm.list = res.data.items
            vm.parsedList = handleList res.data.items, vm.table
            vm.currentPage = (res.data._meta and res.data._meta.currentPage) || 1
            vm.totalItems = (res.data._meta and res.data._meta.totalCount) || 0
            status.hide()
            return
          , (res) ->
            status.error()
        return

      # 获取标头标题们
      vm.getThs = (table) ->
        result = []
        for map in table
          result.push map.text
        result

      # 删除多个条目
      vm.deleteItems = (url, ids) ->
        if confirm(if ids.length > 1 then '确定删除多个条目？' else '确定删除该条目？')
          Util.delete url, {ids: ids.join(',')}
            .then (res) ->
              toastr.success '删除成功'
              vm.pageChanged()

      # tab 切换
      vm.query = (query) ->
        if vm.currentListApi isnt vm.api.list
          resetSendData()
        sendData.page = 1
        getList vm.api.list, angular.extend sendData, query
        vm.currentListApi = vm.api.list
        vm.currentQuery = query

      # 页码修改，重新请求
      vm.pageChanged = () ->
        getList vm.currentListApi, angular.extend sendData, {page: vm.currentPage}

      # 根据字段搜索并加载数据
      _timer = null # 搜索时keyup定时器
      vm.search = (keyword) ->
        $timeout.cancel _timer
        _timer = $timeout ()->
          resetSendData()
          getList vm.api.search, angular.extend sendData, {keyword: keyword}
          vm.currentListApi = vm.api.search
        , 500

      vm.reload = () ->
        vm.pageChanged()

      # 删除
      vm.delete = (index) ->
        ids = []
        if index?
          ids.push vm.list[index].id
        else
          return if vm.selectedItems.length is 0
          for item in vm.selectedItems
            ids.push item.id
        vm.deleteItems vm.api.delete, ids

      # 更新全选状态
      vm.updateCheckedAll = ->
        vm.checkedAll = vm.selectedItems.length and (vm.selectedItems.length is vm.list.length)

      return

    handleApi = (api) ->
      throw new Error "api and api.base must be set" if !api? or !api.base?
      apiTmp = {}
      apiTmp.list = if api.list? then "#{api.base}/#{api.list.replace(/^\//, '')}" else api.base
      apiTmp.search = if api.search? then "#{api.base}/#{api.search.replace(/^\//, '')}" else "#{api.base}/search"
      apiTmp.delete = if api.delete? then "#{api.base}/#{api.delete.replace(/^\//, '')}" else "#{api.base}/more-delete"
      apiTmp.routing = if api.routing? then "#/#{api.routing.replace(/^\//, '')}" else "##{api.base}"
      apiTmp.addrouter = "#{apiTmp.routing}/new"
      apiTmp

    handleAvailable = (available) ->
      if !available?
        return {
          add: true
          delete: true
          search: true
          checkbox: true
          pagination: true
        }
      a = {}
      os = available.split(' ')
      for o in os
        a[o] = true
      a

    isArray = (obj) ->
      Object.prototype.toString.call(obj) is '[object Array]'

    genHandleButtons = (s) ->
      genButtonsHandleName = do ->
        i = 0
        return ->
          i++
          s + i
      (buttons, scope, el, attr, vm) ->
        return unless buttons?
        throw new Error 'buttons must be array' unless isArray buttons
        tmp = []
        for button in buttons
          if button.handle?
            fnName = genButtonsHandleName()
            vm[fnName] = button.handle.bind(vm, scope, el, attr, vm)
            extra = {handle: fnName}
          tmp.push angular.extend {}, button, extra
        tmp
    handleButtons = genHandleButtons('buttons')
    handleBtns = genHandleButtons('btns')

    handleTabs = (tabs) ->
      return unless tabs?
      throw new Error 'tabs must be array' unless isArray tabs
      return [tabs] unless isArray tabs[0]
      tabs

    handleEvents = (events, scope, el, attr, vm) ->
      return if !events?
      for e in events
        el.on e.type, e.selector, (evt) ->
          e.handle evt, this, scope, el, attr, vm
      return

    linkFunc = (scope, el, attr, vm) ->
      throw new Error 'must set grid in controller' if !scope.grid?
      vm.api = handleApi scope.grid.api
      vm.available = handleAvailable scope.grid.available
      vm.buttons = handleButtons scope.grid.buttons, scope, el, attr, vm
      vm.btns = handleBtns scope.grid.btns, scope, el, attr, vm
      vm.tabs = handleTabs scope.grid.tabs
      vm.table = scope.grid.table

      # init
      vm.ths = vm.getThs(vm.table)
      initQuery = {}
      if vm.tabs?
        for tabs in vm.tabs
          for tab in tabs
            if tab.active is true
              angular.extend initQuery, tab.query
      vm.query(initQuery)

      updateSelectedItems = ->
        vm.selectedItems = []
        el.find 'tbody input:checked'
        .each (index, item) ->
          vm.selectedItems.push vm.list[parseInt($(this).val())]

      el.on 'click', 'thead input', (e) ->
        checked = $(this).prop 'checked'
        $cboxs = el.find 'tbody input'
        if checked
          $cboxs
            .prop 'checked', true
            .parents('tr').addClass('active')
          updateSelectedItems()
        else
          $cboxs
            .prop 'checked', false
            .parents('tr').removeClass('active')
          vm.selectedItems = []
        scope.$apply()
        return

      el.on 'click', 'tbody input', (e) ->
        $this = $(this)
        checked = $this.prop 'checked'
        if checked
          $this.parents('tr').addClass('active')
          vm.selectedItems.push vm.list[parseInt($(this).val())]
        else
          $this.parents('tr').removeClass('active')
          for item, i in vm.selectedItems
            if vm.list[parseInt($(this).val())].id is item.id
              vm.selectedItems.splice i, 1
        vm.updateCheckedAll()
        scope.$apply()

      el.on 'click', '.J_delete', (e) ->
        vm.deleteItems vm.api.delete, [$(this).data 'id']

      el.on 'mouseenter', '.J_image', (e) ->
        $(this).addClass 'on'

      el.on 'mouseleave', '.J_image', (e) ->
        $(this).removeClass 'on'

      # 绑定事件
      handleEvents scope.grid.events, scope, el, attr, vm if scope.grid.events?
      scope.grid.callback && scope.grid.callback(scope, el, attr, vm)

      scope.$on '$destroy', ->
        el.off()
        return
      return

    directive =
      restrict: 'E'
      scope:
        grid: '='
      templateUrl: 'app/components/grid/grid.html'
      link: linkFunc
      controller: GridController
      controllerAs: 'vm'
      #bindToController: true
