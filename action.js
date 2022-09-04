const core = require('@actions/core');

function run() {
  try {
    // This is just a thin wrapper around bash
    const script = require('path').resolve(__dirname, 'script.sh');

    var child = require('child_process').execFile(script);
    // child.stderr.on('data', (data) => {
    //   console.warn(data.toString());
    // });
    var all_output = "";
    child.stdout.on('data', (data) => {
      all_output += data.toString();
      process.stdout.write(data.toString());
    });
    child.stderr.on('data', (data) => {
      all_output += data.toString();
    });

    child.on('close', (code) => {
      console.log(`child process exited with code ${code}`);
      if (code != 0) console.error("Error detected. All stdout and stderr outputs:\n" + all_output + "\n");
      process.exit(code);
    });
  }
  catch (error) {
    core.setFailed(error.message);
  }
}

run()
