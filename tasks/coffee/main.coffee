module.exports = (grunt) ->
    grunt.registerMultiTask "ritzau-sprites", "Generate sprite + CSS from the Ritzau logo library", ->
        options = this.options
            css:
                logoPath:   "../../img/ritzau-logos/"
                spritePath: "../../img/sprites/ritzau-logos.png"
                logoPrefix: "ritzau-logo"
            
            files:
                logoPrefix: "ritzau-logo"
        
        if not options.files.sprite or not options.files.stylesheet or not options.files.logos or not options.files.logoPrefix
            grunt.log.error "Please fill out options accordingly"
            return false

        async = require("async")
        SpriteGenerator = require("./lib/generator.js").SpriteGenerator

        tasks = []
        options.done  = this.async()
        options.grunt = grunt

        tasks.push (cb) ->
            new SpriteGenerator("http://epgpack:7777/susepg/REST/channels", options)

        async.series tasks, (error) ->
            if error
                grunt.log.error error
            else
                grunt.log.ok "Yep"