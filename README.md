# Safe Action Debugger

Interactive debugger for GitHub Actions. The connection information can sent to you via Telegram Bot. It also supports attaching docker image/container.

## Usage

Standard:
```yml
steps:
- name: Setup Debug Session
  env:
    TELEGRAM_TOKEN : ${{ secrets.TELEGRAM_TOKEN }}
    TELEGRAM_TO : ${{ secrets.TELEGRAM_TO }}
  uses: garypang13/debugger-action@master
```

Attach to docker container:
```yml
steps:
- name: Setup Debug Session
  env:
    TELEGRAM_TOKEN : ${{ secrets.TELEGRAM_TOKEN }}
    TELEGRAM_TO : ${{ secrets.TELEGRAM_TO }}
  uses: garypang13/debugger-action@master
```

Attach to docker image:
```yml
steps:
- name: Setup Debug Session
  env:
    TMATE_DOCKER_IMAGE: IMAGE_TAG
    TMATE_DOCKER_IMAGE_EXP: IMAGE_TAG
    TELEGRAM_TOKEN : ${{ secrets.TELEGRAM_TOKEN }}
    TELEGRAM_TO : ${{ secrets.TELEGRAM_TO }}
  uses: garypang13/debugger-action@master
```


### Session timeout and message display interval

There is a global timeout after 30 minutes (if you didn't specify other value for `TIMEOUT_MIN`). After you connect to the session, the timeout will be automatically disabled.

The connection info are displayed every 30 seconds. You can customize by setting `DISP_INTERVAL_SEC` env.

### Attach to docker

> The debugger action just attaches to docker image/container, it does not install anything inside. After you quit the docker image, the changes you made will be saved to the original image or specified one.

You can make the debugger attach to specified docker image/container by setting `TMATE_DOCKER_IMAGE` or `TMATE_DOCKER_CONTAINER`. It is easy to switch between Github Actions runner and docker image/container. 

![docker](https://github.com/tete1030/safe-debugger-action/raw/gh-pages/docs/imgs/docker.png)

## Environment variables

- `TIMEOUT_MIN`: timeout in minutes
- `DISP_INTERVAL_SEC`: message display interval in seconds
- `TELEGRAM_TOKEN`: 
- `TELEGRAM_TO`: 
- `TMATE_DOCKER_CONTAINER`: the docker container name
- `TMATE_DOCKER_IMAGE`: the docker image tag
- `TMATE_DOCKER_IMAGE_EXP`: the docker image tag for saving changes you made in debugger. (defaults to `TMATE_DOCKER_IMAGE`)
- `TMATE_TERM`: specify the `TERM` environment variable. (defaults to `screen-256color`)

## Acknowledgments

* P3TERX's [debugger-action](https://github.com/P3TERX/debugger-action)
* [tmate.io](https://tmate.io)
* Max Schmitt's [action-tmate](https://github.com/mxschmitt/action-tmate)
* Christopher Sexton's [debugger-action](https://github.com/csexton/debugger-action)

### License

The action and associated scripts and documentation in this project are released under the MIT License.
