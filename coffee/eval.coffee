evaluation = (options) ->
    cssTemplate    = options.cssTemplate
    channels       = options.channels
    logoPath       = options.logoPath
    filenamePrefix = options.filenamePrefix
    moo = []

    String::replaceObject = (obj) ->
        result = this
        for key of obj
            re     = new RegExp("{#{key}}", "g")
            result = result.replace(re, obj[key])

        return result

    largestImageWithIdent = (ident) ->
        maxWidth = 0
        images   = document.querySelectorAll("img")
        result   = null

        for image in images
            if image.getAttribute("data-ident") isnt ident
                continue

            if image.width > maxWidth
                maxWidth = image.width
                result   = image

        return result
    
    # We need to do multiple loops for this to work; first we calculate the dimensions, then we draw the images
    width  = 0
    height = 0
    css    = ""

    for channel in channels
        image = largestImageWithIdent(channel.ident)
        if image
            moo.push(channel.ident) unless image.height >= 30
            channel.spriteImage = image

            width   = image.width unless width >= image.width
            height += image.height

    canvas = document.getElementById("sprite")
    ctx    = canvas.getContext("2d")
    
    canvas.width  = width
    canvas.height = height
    offset        = 0

    for channel in channels
        continue unless channel.spriteImage
        ctx.drawImage(channel.spriteImage, 0, offset)

        offset += channel.spriteImage.height
        css    += "\n\n" + cssTemplate.replaceObject
            name:     "#{filenamePrefix}-#{channel.ident}"
            width:    channel.spriteImage.width
            height:   channel.spriteImage.height
            pos:      offset - channel.spriteImage.height
            logoName: "#{filenamePrefix}-#{channel.ident}.png"
            logoPath: logoPath

    # FINALLY
    result =
        sprite: JSON.stringify(canvas.toDataURL({format: "png"}))
        css:    css
        width:  width
        height: height
        moo: moo

    return result