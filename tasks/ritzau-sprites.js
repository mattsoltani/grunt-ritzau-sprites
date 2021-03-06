// Generated by CoffeeScript 1.6.3
module.exports = function(grunt) {
  return grunt.registerMultiTask("ritzau-sprites", "Generate sprite + CSS from the Ritzau logo library", function() {
    var SpriteGenerator, async, options, tasks;
    options = this.options({
      css: {
        logoPath: "../../img/ritzau-logos/",
        spritePath: "../../img/sprites/ritzau-logos.png",
        logoPrefix: "ritzau-logo"
      },
      files: {
        logoPrefix: "ritzau-logo"
      }
    });
    if (!options.files.sprite || !options.files.stylesheet || !options.files.logos || !options.files.logoPrefix) {
      grunt.log.error("Please fill out options accordingly");
      return false;
    }
    async = require("async");
    SpriteGenerator = require("./lib/generator.js").SpriteGenerator;
    tasks = [];
    options.done = this.async();
    options.grunt = grunt;
    tasks.push(function(cb) {
      return new SpriteGenerator("http://epgpack:7777/susepg/REST/channels", options);
    });
    return async.series(tasks, function(error) {
      if (error) {
        return grunt.log.error(error);
      } else {
        return grunt.log.ok("Yep");
      }
    });
  });
};
