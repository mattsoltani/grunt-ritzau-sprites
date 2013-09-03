XMLHttpRequest = require('w3c-xmlhttprequest').XMLHttpRequest
fs             = require('fs')
parseXml       = require('xml2js').parseString
http           = require('http')
phantom        = require("phantom")

red    = '\u001b[31m'
blue   = '\u001b[34m'
cyan   = '\u001b[36m'
reset  = '\u001b[0m'
under  = '\u001b[90m'

String::replaceObject = (obj) ->
    result = this
    for key of obj
        re     = new RegExp("{#{key}}", "g")
        result = result.replace(re, obj[key])

    return result

class SpriteGenerator
    cssTemplate:
        """
            .{name} {
                width: {width}px;
                height: {height}px;
                background-image: url("{logoPath}{logoName}");
            }
            .{name}-sprite {
                width: {width}px;
                height: {height}px;
                background-position: 0 -{pos}px;
            }
        """

    cssFooterTemplate:
        """
            /* Default classes */
            [class*="{prefix}"] {
                display: block;
                overflow: hidden;
                background-repeat: no-repeat;
                background-image: none;
                text-indent: -9999px;
            }
            [class*="{prefix}"][class*=-sprite] {
                background-image: url("{spriteUrl}");
            }
        """

    ########################################################################################################################
    ### EPG
    ########################################################################################################################

    constructor: (epgFeedUrl, options) ->
        @start = +new Date()
        @options = options || {}
        @done    = @options.done
        @grunt   = @options.grunt

        @grunt.log.writeln "#{under}>>#{reset} Generating Ritzau logos + sprite ..."

        @epgFeedUrl = epgFeedUrl

        fs.mkdir @options.files.logos, (error) ->
        # WE DONT CARE IF IT FAILS GOD DAMN IT!
        host = require("url").parse(@epgFeedUrl).hostname
        require('dns').lookup host, (error) =>
          if error
            @grunt.log.error "Could not connect to EPG. Check intranet connectivity."
            @grunt.errorCount++
          else
            this.epgRequest()

    ########################################################################################################################
    ### EPG
    ########################################################################################################################

    epgRequest: ->
        @client = new XMLHttpRequest()
        @client.open("GET", @epgFeedUrl)
        @client.addEventListener "load", this.epgRequestCallback, false
        @client.send()

    epgRequestCallback: =>
        data = @client.response
        parseXml data, (error, result) =>
            if result? and result instanceof Object
                @channels = result["m_lcha:message"].channels.pop().channel

                this.parseChannels()

    ########################################################################################################################
    ### Channel parsing
    ########################################################################################################################

    validImageExtension: (channel, string) ->
        valid = [".gif", ".png", ".jpg", ".jpeg"]

        if valid.indexOf(string.substr(string.lastIndexOf("."))) is -1
            @grunt.log.warn "Invalid image extension for #{cyan}#{channel.name}#{reset} #{under}(#{channel.ident})#{reset} - skipping"
            return false

        return true

    parseChannels: ->
        @downloadedImages = 0
        @parsedImages     = 0
        @totalImages      = 0

        for channel, i in @channels
            channel.ident     = [].concat(channel.source_url.toString().split("/")).pop().toLowerCase()
            channel.images    = []
            channel.imageUrls = []

            channel.imageUrls.push(channel.logo_16.toString()) unless not channel.logo_16 or not this.validImageExtension(channel, channel.logo_16.toString())
            channel.imageUrls.push(channel.logo_32.toString()) unless not channel.logo_32 or not this.validImageExtension(channel, channel.logo_32.toString())
            channel.imageUrls.push(channel.logo_50.toString()) unless not channel.logo_50 or not this.validImageExtension(channel, channel.logo_50.toString())

            @totalImages += channel.imageUrls.length

        this.parseImages()

    ########################################################################################################################
    ### Image parsing
    ########################################################################################################################

    parseImages: ->
        for channel, i in @channels
            continue unless channel.imageUrls and channel.imageUrls.length > 0

            for url, j in channel.imageUrls
                this.downloadImages(channel, url, j)

    downloadImages: (channel, url, i) ->
        filename = "#{@options.files.logos}/#{@options.files.logoPrefix}-#{channel.ident}-temp#{i}.png"

        http.get url, (response) =>
            @grunt.log.warn "Failed to download sprite #{cyan}#{url}#{reset} #{under}(#{channel.ident})#{reset} -- Status code: #{response.statusCode}" unless response.statusCode >= 200 and response.statusCode < 400
            response.pipe(fs.createWriteStream(filename)).on "close", =>
                @downloadedImages++

                channel.images.push
                    filename:     filename
                    url:          url
                    dimensions:   null
                    dimensionSum: 0

                if @downloadedImages is @totalImages
                    this.generateSprite()

    generateSprite: ->
        html = """<canvas id="sprite"></canvas>"""
        for channel in @channels
            continue unless channel.imageUrls and channel.imageUrls.length > 0

            for image in channel.images
                html += """<img src="#{image.filename}" data-ident="#{channel.ident}" />"""

        temp = "#{__dirname}/temp.html"
        ws   = fs.createWriteStream(temp)
        ws.write(html)
        ws.close()

        params = 
            channels:       @channels
            cssTemplate:    @cssTemplate
            logoPath:       @options.css.logoPath
            filenamePrefix: @options.css.logoPrefix

        fn = "function() { return (#{evaluation.toString()}).apply(this, #{JSON.stringify([params])});}"

        phantom.create "--local-to-remote-url-access=yes", (ph) =>
            @phantom = ph
            ph.createPage (page) =>
                page.open temp, (status) =>
                    page.evaluate fn, this.pageResult

    ########################################################################################################################
    ### Phantom
    ########################################################################################################################

    didWrite: (error) =>
        if --@jobs is 0
            end = +new Date()
            @grunt.log.ok "Finished in #{end-@start}ms"
            @done()

    pageResult: (result) =>
        @phantom.exit()

        for filename in result.images
            fs.renameSync(filename, filename.replace(/\-temp\d\./gi, "."))

        # Delete temp files
        fs.readdir @options.files.logos, (error, list) =>
            for file in list
                continue unless file.lastIndexOf("temp") isnt -1
                file = "#{@options.files.logos}/#{file}"
                stat = fs.statSync(file)
                if not stat.isDirectory()
                    fs.unlink(file)

            this.didWrite()

        @jobs = 3

        buffer = result.sprite.substring(1, result.sprite.length-2)
        buffer = buffer.replace(/^data:image\/png;base64,/, "")
        fs.writeFile @options.files.sprite, buffer, 'base64', this.didWrite

        css = @cssFooterTemplate.replaceObject
            spriteUrl: @options.css.spritePath
            prefix:    @options.css.logoPrefix
        css += result.css
        fs.writeFile @options.files.stylesheet, css, this.didWrite