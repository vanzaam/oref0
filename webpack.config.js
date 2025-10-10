const path = require('path');
const TerserPlugin = require("terser-webpack-plugin");

module.exports = {
  mode: 'production',
  entry: {
    iob: './lib/iob/index.js',
    meal: './lib/meal/index.js',
    determine_basal: './lib/determine-basal/determine-basal.js',
    glucose_get_last: './lib/glucose-get-last.js',
    basal_set_temp: './lib/basal-set-temp.js',
    autosens: './lib/determine-basal/autosens.js',
    profile: './lib/profile/index.js',
    autotune_prep: './lib/autotune-prep/index.js',
    autotune_core: './lib/autotune/index.js'
  },
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: '[name].js',
    libraryTarget: 'var',
    library: 'freeaps_[name]'
  },
  optimization: {
    minimize: false,
    // minimizer: [new TerserPlugin()],
  },
};
