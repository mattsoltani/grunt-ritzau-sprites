// Generated by CoffeeScript 1.6.3
var evaluation;

evaluation = function(options) {
  var canvas, channel, channels, css, cssTemplate, ctx, filenamePrefix, height, image, largestImageWithIdent, logoPath, offset, result, width, _i, _j, _len, _len1;
  cssTemplate = options.cssTemplate;
  channels = options.channels;
  logoPath = options.logoPath;
  filenamePrefix = options.filenamePrefix;
  String.prototype.replaceObject = function(obj) {
    var key, re, result;
    result = this;
    for (key in obj) {
      re = new RegExp("{" + key + "}", "g");
      result = result.replace(re, obj[key]);
    }
    return result;
  };
  largestImageWithIdent = function(ident) {
    var image, images, maxWidth, result, _i, _len;
    maxWidth = 0;
    images = document.querySelectorAll("img");
    result = null;
    for (_i = 0, _len = images.length; _i < _len; _i++) {
      image = images[_i];
      if (image.getAttribute("data-ident") !== ident) {
        continue;
      }
      if (image.width > maxWidth) {
        result = image;
      }
    }
    return result;
  };
  width = 0;
  height = 0;
  css = "";
  for (_i = 0, _len = channels.length; _i < _len; _i++) {
    channel = channels[_i];
    image = largestImageWithIdent(channel.ident);
    if (image) {
      channel.spriteImage = image;
      if (!(width >= image.width)) {
        width = image.width;
      }
      height += image.height;
    }
  }
  canvas = document.getElementById("sprite");
  ctx = canvas.getContext("2d");
  canvas.width = width;
  canvas.height = height;
  offset = 0;
  for (_j = 0, _len1 = channels.length; _j < _len1; _j++) {
    channel = channels[_j];
    if (!channel.spriteImage) {
      continue;
    }
    ctx.drawImage(channel.spriteImage, 0, offset);
    offset += channel.spriteImage.height;
    css += cssTemplate.replaceObject({
      name: "" + filenamePrefix + "-" + channel.ident,
      width: channel.spriteImage.dimensions.width,
      height: channel.spriteImage.dimensions.height,
      pos: offset - channel.spriteImage.height,
      logoName: "" + filenamePrefix + "-" + channel.ident + ".png",
      logoPath: logoPath
    });
  }
  result = {
    sprite: JSON.stringify(canvas.toDataURL({
      format: "png"
    })),
    css: css
  };
  return result;
};