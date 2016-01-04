angular.module 'jkbs'
  .directive 'grid', ->
    GridController = (Util, $scope, $state, $sce, $timeout, toastr) ->
      'ngInject'
      vm = this
      # 数据和分页
      vm.list = []
      vm.currentPage = 1
      vm.totalItems = 0

      # 状态字段
      vm.isNoData = false
      vm.isLoading = true
      vm.isError = false

      # 其它字段
      vm.currentListApi = '' # 当前请求的地址
      vm.operation = null
      vm.ths = [] # 表头的标题们
      vm.ids = [] # 被选中的条目的 id

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
        vm.tabs && vm.tabs[0].active = true
        vm.tabs2 && vm.tabs2[0].active = true
        sendData = {page: 1, 'per-page': 10}
      vm.toastr = toastr

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
        vm.ids = []
        status.loading()

        Util.get url, data
          .then (res)->
            if !res.data.items or res.data.items.length is 0
              vm.list = []
              status.noData()
              return

            # 赋值
            vm.list = handleList res.data.items, vm.table
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

      # 删除某一个条目
      vm.deleteItem = (url, id) ->
        if confirm '确定删除该条目？'
          Util.delete "#{url}/#{id}", {id: id}
            .then (res) ->
              toastr.success '删除成功'
              vm.pageChanged()

      # 删除多个条目
      vm.deleteItems = (url, ids) ->
        return false if ids.length is 0
        if confirm(if ids.length > 1 then '确定删除多个条目？' else '确定删除该条目？')
          Util.delete url, {ids: ids.join(',')}
            .then (res) ->
              toastr.success '删除成功'
              vm.pageChanged()

      # tab 切换
      vm.switchTab = (query) ->
        if vm.currentListApi isnt vm.api.list
          resetSendData()
        sendData.page = 1
        getList vm.api.list, angular.extend sendData, query
        vm.currentListApi = vm.api.list

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

      # 增加条目
      vm.add = () ->
        $state.go vm.addHref

      # 删除多个
      vm.delete = () ->
        vm.deleteItems vm.api.delete, vm.ids

      return

    handleApi = (api) ->
      throw new Error "api and api.base must be set" if !api? or !api.base?
      api.list = if api.list? then "#{api.base}/#{api.list}" else api.base
      api.search = if api.search? then "#{api.base}/#{api.search}" else "#{api.base}/search"
      api.delete = if api.delete? then "#{api.base}/#{api.delete}" else api.base
      api.addHref = if api.addHref? then "##{api.addHref}/new" else "##{api.base}/new"
      api

    handleOperation = (operation) ->
      if !operation?
        return {
          add: true
          delete: true
          search: true
        }
      a = {}
      os = operation.split(' ')
      for o in os
        a[o] = true
      a

    handleEvents = (events, el) ->
      return if !events?
      for event in events
        el.on event.type, event.selector, event.fn
      return

    linkFunc = (scope, el, attr, vm) ->
      throw new Error 'must set grid in controller' if !scope.grid?
      vm.api = handleApi scope.grid.api
      vm.operation = handleOperation scope.grid.operation
      vm.tabs = scope.grid.tabs
      vm.tabs2 = scope.grid.tabs2
      vm.table = scope.grid.table

      # init
      vm.ths = vm.getThs(vm.table)
      vm.currentListApi = vm.api.list
      vm.reload()

      # 绑定事件
      handleEvents scope.grid.events

      updateIds = ->
        vm.ids = []
        el.find 'tbody input:checked'
        .each (index, item) ->
          vm.ids.push $(item).val()

      el.on 'click', 'thead input', (e) ->
        checked = $(this).prop 'checked'
        $cboxs = el.find 'tbody input'
        if checked
          $cboxs
            .prop 'checked', true
            .parents('tr').addClass('active')
          updateIds()
        else
          $cboxs
            .prop 'checked', false
            .parents('tr').removeClass('active')
          vm.ids = []
        return

      el.on 'click', 'tbody input', (e) ->
        $this = $(this)
        checked = $this.prop 'checked'
        if checked
          $this.parents('tr').addClass('active')
          vm.ids.push $(this).val()
        else
          $this.parents('tr').removeClass('active')
          for id, i in vm.ids
            if $(this).val() is id
              vm.ids.splice i, 1

      el.on 'click', '.J_delete', (e) ->
        vm.deleteItem vm.api.delete, $(this).attr 'alt'

      el.on 'mouseenter', '.J_image', (e) ->
        $(this).addClass 'on'

      el.on 'mouseleave', '.J_image', (e) ->
        $(this).removeClass 'on'

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
