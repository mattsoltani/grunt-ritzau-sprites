XMLHttpRequest = require('w3c-xmlhttprequest').XMLHttpRequest
fs             = require('fs')
parseXml       = require('xml2js').parseString
http           = require('http')
phantom        = require("phantom")

done = this.async() || (->)

class SpriteGenerator
    filenamePrefix:  "ritzau-logo"
    imageDirectory:  "ritzau-logos"
    cssSubDirectory: "ritzau-css"
    logoPath:        "../../img/ritzau-logos/"
    spriteUrl:       "../../img/sprites/ritzau-logos.png"

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

    constructor: (epgFeedUrl, killer) ->
        options = options || {}
        grunt.log.write "Generating Ritzau logos + sprite ..."

        @epgFeedUrl = epgFeedUrl

        @filenamePrefix  = options.filenamePrefix unless not options.filenamePrefix
        @imageDirectory  = options.imageDirectory unless not options.imageDirectory
        @cssSubDirectory = options.cssDirectory unless not options.cssDirectory
        @logoPath        = options.urlLogos unless not options.urlLogos
        @spriteUrl       = options.urlSprite unless not options.urlSprite

        fs.mkdir @imageDirectory, (error) ->
            # WE DONT CARE IF IT FAILS GOD DAMN IT!

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

    parseChannels: ->
        @downloadedImages = 0
        @parsedImages     = 0
        @totalImages      = 0

        for channel, i in @channels
            channel.ident     = [].concat(channel.source_url.toString().split("/")).pop().toLowerCase()
            channel.images    = []
            channel.imageUrls = []

            channel.imageUrls.push(channel.logo_16.toString()) unless not channel.logo_16
            channel.imageUrls.push(channel.logo_32.toString()) unless not channel.logo_32
            channel.imageUrls.push(channel.logo_50.toString()) unless not channel.logo_50

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
        filename = "#{@imageDirectory}/#{@filenamePrefix}-#{channel.ident}-temp#{i}.png"

        http.get url, (response) =>
            grunt.log.warn "Failed to download sprite (#{url} @ #{channel.ident}) -- Status code: #{response.statusCode}" unless response.statusCode >= 200 and response.statusCode < 400
            response.pipe(fs.createWriteStream(filename)).on "close", =>
                @downloadedImages++

                channel.images.push
                    filename:     "#{__dirname}/#{filename}"
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
            logoPath:       @logoPath
            filenamePrefix: @filenamePrefix

        fn = "function() { return (#{evaluation.toString()}).apply(this, #{JSON.stringify([params])});}"

        phantom.create "--local-to-remote-url-access=yes", (ph) =>
            @phantom = ph
            ph.createPage (page) =>
                page.open temp, (status) =>
                    page.evaluate fn, this.pageResult

    ########################################################################################################################
    ### Phantom
    ########################################################################################################################

    pageResult: (result) =>
        @phantom.exit()
        console.log JSON.stringify(result.moo)

        buffer = result.sprite.substring(1, result.sprite.length-2)
        buffer = buffer.replace(/^data:image\/png;base64,/, "")

        fs.writeFile "#{__dirname}/out.png", buffer, 'base64', (error) ->
            if error
                grunt.log.error "Failed to save sprite"
            else
                grunt.log.ok "Sprite saved"

        fs.writeFile "#{__dirname}/out.css", result.css, (error) ->
            if error
                grunt.log.error "Failed to save stylesheet"
            else
                grunt.log.ok "Stylesheet saved"

        done()

new SpriteGenerator("http://epgpack:7777/susepg/REST/channels", (->))