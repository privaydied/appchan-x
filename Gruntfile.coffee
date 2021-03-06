module.exports = (grunt) ->
  grunt.util.linefeed = '\n'

  importCSS = (filename) ->
     "\"\"\"#{grunt.file.read("src/General/css/#{filename}.css").replace(/\s+/g, ' ').replace(/\r/g, '').trim()}\"\"\""

  importHTML = (filename) ->
    "(innerHTML: #{JSON.stringify(grunt.file.read("src/General/html/#{filename}.html").replace(/^ +| +$</gm, '').replace(/\r?\n/g, '')).replace(/\\\\u/g, '\\u')})"

  html = (template) ->
    parts = template.split /([\$&@]){([^}`]*)}/
    parts2 = []
    checkText = ''
    for part, i in parts
      switch i % 3
        when 0
          parts2.push JSON.stringify part unless part is ''
          checkText += part
        when 1
          if /<[^>]*$/.test(checkText) and not (part is '$' and /\=['"][^"'<>]*$/.test checkText)
            throw new Error "Illegal insertion into HTML template: #{template}"
          parts2.push switch part
            when '$' then "E(`#{parts[i+1]}`)"
            when '&' then "`#{parts[i+1]}`.innerHTML"
            when '@' then "`#{parts[i+1]}`.map((x) -> x.innerHTML).join('')"
    unless /^(<\w+( [\w-]+(='[^"'<>]*'|="[^"'<>]*")?)*>|<\/\w+>|[^"'<>]*)*$/.test checkText
      throw new Error "HTML template is ill-formed: #{template}"
    output = if parts2.length is 0 then '""' else parts2.join ' + '
    "(innerHTML: #{output})"

  assert = (statement, objs...) ->
    return '' unless grunt.config('pkg').tests_enabled
    "throw new Error 'Assertion failed: ' + `#{JSON.stringify statement}` unless #{statement}"

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    concat:
      options: process: Object.create(null, data:
        get: ->
          pkg = grunt.config 'pkg'
          pkg.importHTML = importHTML
          pkg.importCSS  = importCSS
          pkg.html = html
          pkg.assert = assert
          pkg.tests_enabled or= false
          pkg
        enumerable: true
      )
      coffee:
        src: [
          'src/General/Cheats.coffee'
          'src/General/Config.coffee'
          'src/General/Globals.coffee'
          'src/General/Mascots.coffee'
          'src/General/Themes.coffee'
          'src/General/lib/*.coffee'
          'src/General/Header.coffee'
          'src/General/Index.coffee'
          'src/General/Build.coffee'
          'src/General/Get.coffee'
          'src/General/UI.coffee'
          'src/General/CrossOrigin.coffee'
          'src/Filtering/**/*.coffee'
          'src/Quotelinks/**/*.coffee'
          'src/Posting/**/Captcha.coffee'
          'src/Posting/**/Captcha.*.coffee'
          'src/Posting/**/QR.coffee'
          'src/Posting/**/QR.*.coffee'
          'src/Images/**/*.coffee'
          'src/Linkification/**/*.coffee'
          'src/Menu/**/*.coffee'
          'src/Monitoring/**/*.coffee'
          'src/Archive/**/*.coffee'
          'src/Miscellaneous/**/*.coffee'
          'src/Theming/**/*.coffee'
          'src/General/Navigate.coffee'
          'src/General/Settings.coffee'
          'src/General/Main.coffee'
        ]
        dest: 'tmp-<%= pkg.type %>/script.coffee'

      meta:
        files:
          'LICENSE':   'src/General/meta/banner.js'

      crx:
        files:
          'builds/crx/manifest.json': 'src/General/meta/manifest.json'
          'builds/crx/script.js': [
            'src/General/meta/botproc.js'
            'src/General/meta/banner.js'
            'src/General/meta/usestrict.js'
            'tmp-<%= pkg.type %>/script.js'
          ]
      userscript:
        files:
          'builds/<%= pkg.name %>.meta.js': 'src/General/meta/metadata.js'
          'builds/<%= pkg.name %>.user.js': [
            'src/General/meta/botproc.js'
            'src/General/meta/metadata.js'
            'src/General/meta/banner.js'
            'src/General/meta/usestrict.js'
            'tmp-<%= pkg.type %>/script.js'
          ]
    copy:
      crx:
        src:  'src/General/img/*.png'
        dest: 'builds/crx/'
        expand:  true
        flatten: true

    coffee:
      script:
        src:  'tmp-<%= pkg.type %>/script.coffee'
        dest: 'tmp-<%= pkg.type %>/script.js'

    concurrent:
      build: [
        'concat:meta'
        'build-crx'
        'build-userscript'
      ]

    bump:
      options:
        updateConfigs: [
          'pkg'
        ]
        commit:    false
        createTag: false
        push:      false

    shell:
      checkout:
        command: 'git checkout <%= pkg.meta.mainBranch %>'
      commit:
        command: [
          'git commit -am "Release <%= pkg.meta.name %> v<%= pkg.meta.version %>."'
          'git tag -a <%= pkg.meta.version %> -m "<%= pkg.meta.name %> v<%= pkg.meta.version %>."'
          'git tag -af stable -m "<%= pkg.meta.name %> v<%= pkg.meta.version %>."'
        ].join " && "
      push:
        command: 'git push origin --tags -f && git push origin --all'

    watch:
      options:
        interrupt: true
      all:
        files: [
          'Gruntfile.coffee'
          'package.json'
          'src/**/*'
        ]
        tasks: 'build'

    compress:
      crx:
        options:
          archive: 'builds/<%= pkg.name %>.zip'
          level: 9
          pretty: true
        expand:  true
        flatten: true
        src: 'builds/crx/*'
        dest: '/'
    clean:
      builds: 'builds'
      tmpcrx: 'tmp-crx'
      tmpuserscript: 'tmp-userscript'

  require('load-grunt-tasks') grunt

  grunt.registerTask 'default', [
    'build'
  ]

  grunt.registerTask 'set-build', 'Set the build type variable', (type) ->
    pkg = grunt.config 'pkg' 
    pkg.type = type;
    grunt.config 'pkg', pkg

    [
      pkg.filter
      pkg.flex
      pkg.order
      pkg.align
      pkg.justify
      pkg.transform
    ] = if type is 'crx' then [
      '-webkit-filter'
      '-webkit-flex'
      '-webkit-order'
      '-webkit-align'
      '-webkit-justify-content'
      '-webkit-transform'
    ] else [
      'filter'
      'flex'
      'order'
      'align'
      'justify-content'
      'transform'
    ]

    grunt.log.ok 'pkg.type = %s', type

  grunt.registerTask 'build', [
    'concurrent:build'
  ]

  grunt.registerTask 'build-crx', [
    'set-build:crx'
    'concat:coffee'
    'coffee:script'
    'concat:crx'
    'copy:crx'
    'clean:tmpcrx'
  ]

  grunt.registerTask 'build-userscript', [
    'set-build:userscript'
    'concat:coffee'
    'coffee:script'
    'concat:userscript'
    'clean:tmpuserscript'
  ]

  grunt.registerTask 'release', [
    'build'
    'compress:crx'
    'shell:commit'
    'shell:push'
  ]
  grunt.registerTask 'patch', [
    'bump'
    'updcl:3'
  ]

  grunt.registerTask 'minor', [
    'bump:minor'
    'updcl:2'
  ]

  grunt.registerTask 'major', [
    'bump:major'
    'updcl:1'
  ]

  grunt.registerTask 'updcl', 'Update the changelog', (headerLevel) ->
    headerPrefix = new Array(+headerLevel + 1).join '#'
    {meta} = grunt.config 'pkg'
    {version} = meta
    today     = grunt.template.today 'yyyy-mm-dd'
    changelog = grunt.file.read 'CHANGELOG.md'

    grunt.file.write 'CHANGELOG.md', "#{headerPrefix} v#{version} \n*#{today}*\n\n#{changelog}"
    grunt.log.ok "Changelog updated for v#{version}."
