const webpack = require('webpack')
const path = require('path')
const nodeExternals = require('webpack-node-externals')
const StartServerPlugin = require('start-server-webpack-plugin')

module.exports = {
    entry: [
        './src/server/index'
    ],
    watch: true,
    target: 'node',
    module: {
        rules: [{
            test: /\.js?$/,
            use: 'babel-loader',
            exclude: /node_modules/
        }]
    },
    plugins: [
        new StartServerPlugin('server.js'),
        new webpack.NamedModulesPlugin(),
        new webpack.NoEmitOnErrorsPlugin(),
        new webpack.DefinePlugin({
            "process.env": {
                "BUILD_TARGET": JSON.stringify('server')
            }
        }),
        new webpack.IgnorePlugin(/^electron$/)
    ],
    externals: {
        electron: "electron",
    },
    output: {
        path: path.join(__dirname, 'prod/server'),
        filename: 'server.js'
    }
}
