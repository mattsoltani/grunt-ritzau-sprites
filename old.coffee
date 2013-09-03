XMLHttpRequest = require('w3c-xmlhttprequest').XMLHttpRequest
fs             = require('fs')
xmlParser      = require('xml2json')
gm             = require('gm')
http           = require('http')
phantom        = require("phantom")
portscanner    = require("portscanner")

String::replaceObject = (obj) ->
    result = this
    for key of obj
        re     = new RegExp("{#{key}}", "g")
        result = result.replace(re, obj[key])

    return result

class SpriteGenerator
    filenamePrefix:  "ritzau-logo"
    subDirectory:    "ritzau-logos"
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

    constructor: (epgFeedUrl, killer, options) ->
        options = options || {}
        console.log "Generating Ritzau logos + sprite ..."

        @filenamePrefix  = options.filenamePrefix unless not options.filenamePrefix
        @subDirectory    = options.imageDirectory unless not options.imageDirectory
        @cssSubDirectory = options.cssDirectory unless not options.cssDirectory
        @logoPath        = options.urlLogos unless not options.urlLogos
        @spriteUrl       = options.urlSprite unless not options.urlSprite

        @killer = killer
        @channels    = []
        @images      = []

        @downloadedImages = 0
        @parsedImages     = 0
        @totalImages      = 0
        @port = 12300

        # Ensure logo directory exists
        dir = @subDirectory
        fs.exists dir, (exists) ->
            if not exists
                fs.mkdir dir, (error) ->
                    if error
                        console.log "Failed to create directory", error

        @client = new XMLHttpRequest()
        @client.open("GET", epgFeedUrl)
        @client.addEventListener "load", this.requestCallback, false
        @client.send()

    # Stuff and weird .. things

    getImageSize: (filename, callback) ->
        fs.exists filename, (exists) =>
            if not exists
                callback(filename, false)
                return

            try
                options = 
                    port: @port++

                openCallback = (status) =>
                            @page.evaluate (-> document.getElementsByTagName("img")), (result) =>
                                if not result or result.length is 0
                                    callback(filename, true)
                                else
                                    callback(filename, false, width: result[0].width, height: result[0].height)

                if not @page
                    @phantom = phantom.create options, (ph) =>
                        ph.createPage (page) =>
                            @page = page
                            @page.open filename, openCallback

                    @phantom.on "error", (e) ->
                        callback(filename, true)
                else
                    @page.open filename, openCallback
            catch e
                callback(filename, true)
        

    # MEH

    requestCallback: =>
        data = @client.response
        json = xmlParser.toJson data,
            object: true
        
        return console.error "Failed to fetch channel list from service: #{@serviceUrl}" unless json

        @channels = json["m_lcha:message"].channels.channel

        this.parseChannels()

    parseChannels: ->
        for channel, i in @channels
            channel.ident     = [].concat(channel.source_url.split("/")).pop().toLowerCase()
            channel.images    = []
            channel.imageUrls = []

            channel.imageUrls.push(channel.logo_16) unless not channel.logo_16
            channel.imageUrls.push(channel.logo_32) unless not channel.logo_32
            channel.imageUrls.push(channel.logo_50) unless not channel.logo_50

            @totalImages += channel.imageUrls.length

        this.parseImages()

    parseImages: ->
        for channel, i in @channels
            continue unless channel.imageUrls and channel.imageUrls.length > 0

            for url, j in channel.imageUrls
                this.downloadImages(channel, url, j)

    downloadImages: (channel, url, i) ->
        filename = "#{@subDirectory}/#{@filenamePrefix}-#{channel.ident}-temp#{i}.png"
        http.get url, (response) =>
            response.pipe(fs.createWriteStream(filename)).on "close", =>
                @downloadedImages++

                channel.images.push
                    filename:     "#{__dirname}/#{filename}"
                    url:          url
                    dimensions:   null
                    dimensionSum: 0

                if @downloadedImages is @totalImages
                    this.parseImageSizes()

    parseImageSizes: ->
        # Build HTML file
        html = """
        <script type="text/javascript">
        function largestSpriteWithIdent(ident) {
            var maxWidth = 0;
            var images   = document.querySelectorAll("img");
            var result   = null;

            for(var i=0;i<images.length;i++) {
                var image = images[i];
                if (image.getAttribute("data-name") != ident)
                    continue;

                maxHeight += image.height;
                if (image.width > maxWidth) {
                    maxWidth = image.width;
                    result   = image;
                }
            }

            return result;
        }

        function renderSprite(options) {
            options = options || {};
            
            var images = document.querySelectorAll("img");
            var canvas = document.getElementById("sprite");
            var ctx    = canvas.getContext("2d");
            var logos  = [];

            var maxWidth = 0, maxHeight = 0;

            for(var i=0;i<images.length;i++) {
                var image = images[i];

                maxHeight += image.height;
                if (maxWidth < image.width)
                    maxWidth = image.width;
            }

            canvas.height = maxHeight;
            canvas.width  = maxWidth;

            var offset = 0;
            for(var i=0;i<images.length;i++) {
                var image = images[i];
                ctx.drawImage(image, 0, offset);
                logos.push({
                    "name": image.getAttribute("data-name"),
                    "offset": offset
                });

                offset += image.height;
            }

            return {
                "sprite": JSON.stringify(canvas.toDataURL({format: "png"})),
                "logos":  logos
            };
        }
        </script>
        <canvas id="sprite"></canvas>
        """

        n = 0
        for channel, i in @channels
            continue unless channel.imageUrls and channel.imageUrls.length > 0

            for image in channel.images
                html += """<img src="#{image.filename}" id="img#{n++}" data-name="#{channel.ident}" />"""

        temp = "#{__dirname}/temp.html"
        ws = fs.createWriteStream(temp)
        ws.write(html)
        ws.close()

        meh = =>
            return [].map.call document.querySelectorAll("img"), (img) =>
                return width: img.width, height: img.height, src: img.src.replace("file://", "")

        maxWidth = maxHeight = 0
        phantom.create '--local-to-remote-url-access=yes', (ph) =>
            ph.createPage (page) =>
                page.open temp, (status) =>
                    page.evaluate (meh), (images) =>
                        for img in images
                            maxHeight += img.height
                            maxWidth   = img.width unless img.width < maxWidth

                        page.evaluate (-> renderSprite()), (data) ->
                            console.log JSON.stringify(data.logos)

                            sprite = data.sprite.substring(1, data.length-2)
                            sprite = sprite.replace(/^data:image\/png;base64,/, "")
                            fs.writeFile "#{__dirname}/out.png", sprite, 'base64', (error) ->
                                console.log error

                            ph.exit()

        return

        @phantom.on "error", (e) ->
            callback(filename, true)

        for channel, i in @channels
            continue unless channel.imageUrls and channel.imageUrls.length > 0

            for image in channel.images
                continue unless image.dimensionSum is 0
                this.getImageSize image.filename, (filename, error, size) =>
                    @parsedImages++

                    if not error and size
                        image.dimensions   = size
                        image.dimensionSum = size.width * size.height

                        if channel.imageUrls.length is channel.images.length
                            maxSum   = 0
                            curImage = null
                            for image, j in channel.images
                                continue unless image

                                if image.dimensionSum <= maxSum
                                    fs.unlink(image.filename, (->))
                                else
                                    fs.unlink(curImage.filename, (->)) unless not curImage
                                    maxSum   = image.dimensionSum
                                    curImage = image

                            new_filename = "#{@subDirectory}/#{@filenamePrefix}-#{channel.ident}.png"
                            fs.rename(curImage.filename, new_filename)
                            curImage.filename = new_filename
                            channel.image = curImage
                    else
                        image.dimensionSum = -1
                        fs.unlink(filename, (->))

                    if @parsedImages is @totalImages
                        this.generateSprite()
                    else
                        this.parseImageSizes()

                return

    generateSprite: ->
        width  = 0
        height = 0
        for channel in @channels
            continue unless channel.image

            width  = channel.image.dimensions.width unless channel.image.dimensions.width < width
            height += channel.image.dimensions.height

        g   = gm(width, 1, "#ffffffff")
        ws  = fs.createWriteStream("#{@cssSubDirectory}/ritzau-logos.css")

        spritePath = "#{@subDirectory}/ritzau-logos.png"

        css = @cssFooterTemplate.replaceObject
            prefix:     @filenamePrefix
            spriteUrl:  @spriteUrl

        offset = 1
        for channel in @channels
            continue unless channel.image
            g.append(channel.image.filename)

            css += "\n" + @cssTemplate.replaceObject
                name:     "#{@filenamePrefix}-#{channel.ident}"
                width:    channel.image.dimensions.width
                height:   channel.image.dimensions.height
                pos:      offset
                logoName: "#{@filenamePrefix}-#{channel.ident}.png"
                logoPath: @logoPath

            offset += channel.image.dimensions.height

        ws.write(css)
        ws.close()

        g.write spritePath, (error) ->
            if error
                console.log "Error during sprite generation: ", error.code
            else
                console.log "Job done!"

        @killer()

#this.async()
new SpriteGenerator("http://epgpack:7777/susepg/REST/channels", (->))