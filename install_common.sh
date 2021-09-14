#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

blue() {
    echo -e "\033[34m\033[01m$1\033[0m"
}
green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}
red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

# Make sure only root can run our script
# Check if user is root
[ $(id -u) != "0" ] && {
    echo "Error: You must be root to run this script"
    exit 1
}

if [ "$(uname -r | awk -F- '{print $3}' 2>/dev/null)" == "Microsoft" ]; then
    Wsl=true
fi

iptables_flag=y # Install the iptables firewall (y is yes,n is no)
ssh_port=22     # ssh default port

# Software version
GIT_VERSION=2.32.0
PYTHON_VERSION=3.7.11
OPENSSL_VERSION=1.1.1k    # https://www.openssl.org/source/openssl-1.1.1i.tar.gz
SETUPTOOLS_VERSION=57.0.0 # version number changes, url may also change    https://pypi.org/project/setuptools/#files
PIP_VERSION=21.1.2        # version number changes, url may also change  http://mirrors.linuxeye.com/oneinstack/src/   https://pypi.org/project/pip/#files
NODE_VERSION=14.15.4
VIM_VERSION=8.2

# installation path
python_install_dir=/usr/local/python
openssl_install_dir=/usr/local/openssl

# set the default timezone
timezone=Asia/Shanghai

THREAD=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)

Check_Os() {
    green " "
    green " "
    green "================================="
    blue "  开始检测系统..."
    green "================================="
    sleep 2s
    if [ -e "/usr/bin/yum" ]; then
        PM=yum
        if [ -e /etc/yum.repos.d/CentOS-Base.repo ] && grep -Eqi "release 6." /etc/redhat-release; then
            sed -i "s@centos/\$releasever@centos-vault/6.10@g" /etc/yum.repos.d/CentOS-Base.repo
            sed -i 's@centos/RPM-GPG@centos-vault/RPM-GPG@g' /etc/yum.repos.d/CentOS-Base.repo
            [ -e /etc/yum.repos.d/epel.repo ] && rm -f /etc/yum.repos.d/epel.repo
        fi
        if ! command -v lsb_release >/dev/null 2>&1; then
            if [ -e "/etc/euleros-release" ]; then
                yum -y install euleros-lsb
            elif [ -e "/etc/openEuler-release" -o -e "/etc/openeuler-release" ]; then
                if [ -n "$(grep -w '"20.03"' /etc/os-release)" ]; then
                    rpm -Uvh https://repo.openeuler.org/openEuler-20.03-LTS-SP1/everything/aarch64/Packages/openeuler-lsb-5.0-1.oe1.aarch64.rpm
                else
                    yum -y install openeuler-lsb
                fi
            else
                yum -y install redhat-lsb-core
            fi
            clear
        fi
    fi
    if [ -e "/usr/bin/apt-get" ]; then
        PM=apt-get
        command -v lsb_release >/dev/null 2>&1 || {
            apt-get -y update >/dev/null
            apt-get -y install lsb-release
            clear
        }
    fi

    AliyunCheck=$(cat /etc/redhat-release | grep "Aliyun Linux")
    Centos8Check=$(cat /etc/redhat-release | grep ' 8.' | grep -iE 'centos|Red Hat')

    command -v lsb_release >/dev/null 2>&1 || {
        echo "${CFAILURE}${PM} source failed! ${CEND}"
        kill -9 $$
    }

    # Get OS Version
    OS=$(lsb_release -is)
    if [[ "${OS}" =~ ^CentOS$|^CentOSStream$|^RedHat$|^Rocky$|^Fedora$|^Amazon$|^Alibaba$|^Aliyun$|^EulerOS$|^openEuler$ ]]; then
        LikeOS=CentOS
        CentOS_ver=$(lsb_release -rs | awk -F. '{print $1}' | awk '{print $1}')
        [[ "${OS}" =~ ^Fedora$ ]] && [ ${CentOS_ver} -ge 19 ] >/dev/null 2>&1 && {
            CentOS_ver=7
            Fedora_ver=$(lsb_release -rs)
        }
        [[ "${OS}" =~ ^Amazon$|^Alibaba$|^Aliyun$|^EulerOS$|^openEuler$ ]] && CentOS_ver=7
    elif [[ "${OS}" =~ ^Debian$|^Deepin$|^Uos$|^Kali$ ]]; then
        LikeOS=Debian
        Debian_ver=$(lsb_release -rs | awk -F. '{print $1}' | awk '{print $1}')
        [[ "${OS}" =~ ^Deepin$|^Uos$ ]] && [[ "${Debian_ver}" =~ ^20$ ]] && Debian_ver=10
        [[ "${OS}" =~ ^Kali$ ]] && [[ "${Debian_ver}" =~ ^202 ]] && Debian_ver=10

        if [ -f "/etc/update-motd.d/10-uname" ]; then
            sed -i "s@uname -snrvm@#uname -snrvm@" /etc/update-motd.d/10-uname
        fi
    elif [[ "${OS}" =~ ^Ubuntu$|^LinuxMint$|^elementary$ ]]; then
        LikeOS=Ubuntu
        Ubuntu_ver=$(lsb_release -rs | awk -F. '{print $1}' | awk '{print $1}')
        if [[ "${OS}" =~ ^LinuxMint$ ]]; then
            [[ "${Ubuntu_ver}" =~ ^18$ ]] && Ubuntu_ver=16
            [[ "${Ubuntu_ver}" =~ ^19$ ]] && Ubuntu_ver=18
            [[ "${Ubuntu_ver}" =~ ^20$ ]] && Ubuntu_ver=20
        fi
        if [[ "${OS}" =~ ^elementary$ ]]; then
            [[ "${Ubuntu_ver}" =~ ^5$ ]] && Ubuntu_ver=18
            [[ "${Ubuntu_ver}" =~ ^6$ ]] && Ubuntu_ver=20
        fi
        if [[ "${OS}" =~ ^Ubuntu$ ]]; then
            echo '' >/etc/update-motd.d/10-help-text
            if [ -f "/etc/update-motd.d/00-header" ]; then
                sed -i "s@printf \"Welcome to@#printf \"Welcome to@" /etc/update-motd.d/00-header
            fi
        fi
    fi

    # Check OS Version
    if [ ${CentOS_ver} -lt 6 ] >/dev/null 2>&1 || [ ${Debian_ver} -lt 8 ] >/dev/null 2>&1 || [ ${Ubuntu_ver} -lt 16 ] >/dev/null 2>&1; then
        echo "${CFAILURE}Does not support this OS, Please install CentOS 6+,Debian 8+,Ubuntu 16+ ${CEND}"
        kill -9 $$
    fi

    command -v gcc >/dev/null 2>&1 || $PM -y install gcc
    gcc_ver=$(gcc -dumpversion | awk -F. '{print $1}')
}

# install openssl
Install_Openssl() {
    green " "
    green " "
    green "================================="
    blue "  开始安装openssl..."
    green "================================="

    current_openssl_version=$(echo $(openssl version -a) | cut -c 8-14)
    # openssl_version=$(openssl version|grep -Eo '[0-9]\.[0-9]\.[0-9]')
    if [ -e "${openssl_install_dir}/lib/libssl.a" ]; then
        if [[ ${current_openssl_version} == ${OPENSSL_VERSION} ]]; then
            green "=========================================================="
            red "openSSL already installed! Openssl Version: ${current_openssl_version}"
            green "=========================================================="
            sleep 2s
        fi
    else
        if [ -f /usr/bin/openssl ]; then
            mv /usr/bin/openssl /usr/bin/openssl.old
        fi
        pushd /opt >/dev/null
        src_url=https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz && Download_Src
        tar xzf openssl-$OPENSSL_VERSION.tar.gz
        pushd openssl-${OPENSSL_VERSION} >/dev/null
        make clean
        ./config -Wl,-rpath=${openssl_install_dir}/lib -fPIC --prefix=${openssl_install_dir} --openssldir=${openssl_install_dir}
        make depend
        make -j ${THREAD} && make install
        popd >/dev/null
        # ln -s /usr/local/ssl/lib/libssl.so.1.1 /usr/lib64/libssl.so.1.1
        # ln -s /usr/local/ssl/lib/libcrypto.so.1.1 /usr/lib64/libcrypto.so.1.1
        # echo "/usr/local/ssl/lib" >> /etc/ld.so.conf
        # ldconfig

        ln -sf ${openssl_install_dir}/bin/openssl /usr/bin/openssl
        if [ -f "${openssl_install_dir}/lib/libcrypto.a" ]; then
            green "=========================================================="
            red "openssl installed successfully!"
            green "=========================================================="
            /bin/cp cacert.pem ${openssl_install_dir}/cert.pem
            rm -rf openssl-${OPENSSL_VERSION}
        else
            red "=========================================================="
            red "openSSL install failed, Please contact the author!" && lsb_release -a
            red "=========================================================="
            kill -9 $$
        fi
        popd >/dev/null
    fi
}

# install composer
Install_Composer() {
    green " "
    green " "
    green "================================="
    blue "  开始安装Composer..."
    green "================================="
    sleep 2s
    if [ ! -e /usr/bin/composer ] && [ ! -e /usr/local/bin/composer ]; then
        echo "Ready to install Composer...":
        if [ -e /usr/local/php/bin/php ]; then
            if [ ! -f composer.phar ]; then
                /usr/local/php/bin/php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
                /usr/local/php/bin/php -r "if (hash_file('sha384', 'composer-setup.php') === '756890a4488ce9024fc62c56153228907f1545c228516cbf63f885e036d37e9a59d27d63f46af1d4d07ee0f76181c7d3') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
                /usr/local/php/bin/php composer-setup.php
                /usr/local/php/bin/php -r "unlink('composer-setup.php');"
            fi

            if [ -f composer.phar ]; then
                cp composer.phar /usr/local/bin/composer
                ln -s /usr/local/bin/composer /usr/bin/composer
                composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/
            fi
        else
            red "=========================================================="
            red "Skipped installation, PHP not found"
            red "=========================================================="
        fi
    fi
}

# install phpcs and phpmd
Install_Php_Assist() {
    green " "
    green " "
    green "================================="
    blue "  开始安装phpcs and phpmd..."
    green "================================="
    sleep 2s
    curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar
    mv phpcs.phar /usr/local/bin/phpcs && chmod +x /usr/local/bin/phpcs

    curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar
    mv phpcbf.phar /usr/local/bin/phpcbf && chmod +x /usr/local/bin/phpcbf

    curl -OL https://github.com/phpmd/phpmd/releases/download/2.6.1/phpmd.phar
    mv phpmd.phar /usr/local/bin/phpmd && chmod +x /usr/local/bin/phpmd
}

# install git
Install_Git() {
    green " "
    green " "
    green "================================="
    blue "  开始安装Git..."
    green "================================="
    sleep 2s
    current_git_version=$($(git --version | grep git) | cut -c 13-)

    if [[ ${current_git_version} != ${GIT_VERSION} ]]; then
        pushd /opt >/dev/null
        echo "Ready to install Git...":
        if [[ "${LikeOS}" == "CentOS" ]]; then
            yum -y remove git
        elif [[ "${LikeOS}" =~ ^Ubuntu$|^Debian$ ]]; then
            apt-get -y remove git
        fi

        src_url=https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz && Download_Src
        # src_url=https://www.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz && Download_Src
        tar xzf git-$GIT_VERSION.tar.gz
        pushd git-$GIT_VERSION/
        make configure
        ./configure && make -j ${THREAD} prefix=/usr all && make install

        if [ -f /usr/local/bin/git ]; then
            rm -fr /usr/bin/git
            ln -s /usr/local/bin/git /usr/bin/git

            git config --global alias.co checkout &&
                git config --global alias.br branch &&
                git config --global alias.ci commit &&
                git config --global alias.st status &&
                git config --global alias.last 'log -1 HEAD' &&
                git config --global core.autocrlf "input" &&
                git config --global http.postBuffer 524288000 &&
                git config --global core.editor /usr/bin/vim &&
                git config --global http.sslverify false
        fi
        popd >/dev/null
        rm -fr git-$GIT_VERSION*
        popd >/dev/null
    fi
}

# install vim
Install_Vim() {
    green " "
    green " "
    green "================================="
    blue "  开始安装Vim..."
    green "================================="
    sleep 2s
    current_vim_version=$(vim --version 2>&1 | sed '1!d' | sed -e 's/[(][^)]*[)]//' | sed -e 's/[ \t]*$//' | sed -r 's/.*(.{3})/\1/')

    if [[ ${current_vim_version} != ${VIM_VERSION} ]]; then
        pushd /opt >/dev/null
        if [ -f /usr/bin/git ]; then
            #git clone https://github.com/vim/vim.git
            git clone https://codechina.csdn.net/mirrors/vim/vim.git

            if [ -d /opt/vim/src ]; then
                rm -fr ~/.vim_runtime && echo '' >~/.vimrc

                pushd vim/src >/dev/null
                make -j ${THREAD}
                cp -r /opt/vim/src/vim /usr/bin/
                mkdir -p /usr/local/share/vim/ && cp -r /opt/vim/runtime/* /usr/local/share/vim
                mv /usr/bin/vi /usr/bin/vi.old && ln -sf /usr/bin/vim /usr/bin/vi
                popd >/dev/null
                pushd /opt >/dev/null
                rm -fr vim
                popd >/dev/null
            else
                popd >/dev/null
                red "================================="
                red "  Error: vim installed failed...."
                red "================================="
                exit 1
            fi
        else
            red "================================="
            red "  Error: git installed failed..."
            red "================================="
            exit 1
        fi
        popd >/dev/null
    fi

    if [ ! -d ~/.vim_runtime ]; then
        echo '' >~/.vimrc
        #git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime && sh ~/.vim_runtime/install_awesome_vimrc.sh
        git clone --depth=1 https://codechina.csdn.net/IndexTank/vimrc.git ~/.vim_runtime && sh ~/.vim_runtime/install_awesome_vimrc.sh
        rm -fr ~/.vim_runtime/sources_non_forked/vim-fugitive/plugin/fugitive.vim
        rm -fr ~/.vim_runtime/sources_non_forked/tlib/plugin/02tlib.vim
        touch ~/.vim_runtime/my_configs.vim && cat >~/.vim_runtime/my_configs.vim <<EOF
" 设置通用缩进策略 [四空格缩进]
set shiftwidth=4
set tabstop=4

"" 对部分语言设置单独的缩进 [两空格缩进]
au FileType scheme,racket,lisp,clojure,lfe,elixir,eelixir,ruby,eruby,coffee,slim<Plug>PeepOpenug,scss set shiftwidth=2
au FileType scheme,racket,lisp,clojure,lfe,elixir,eelixir,ruby,eruby,coffee,slim<Plug>PeepOpenug,scss set tabstop=2

"" 配置 Rust 支持 [需要使用 cargo 安装 racer 和 rustfmt 才能正常工作，RUST_SRC_PATH 需要自己下载 Rust           源码并指定好正确的路径]
let $RUST_SRC_PATH                 = $HOME.'/code/data/sources/languages/rust/src'
let g:racer_experimental_completer = 1  " 补全时显示完整的函数定义
let g:rustfmt_autosave             = 1  " 保存时自动格式化代码

set backspace=2              " 设置退格键可用
set autoindent               " 自动对齐
set ai!                      " 设置自动缩进
set smartindent              " 智能自动缩进
set relativenumber           " 开启相对行号
set nu!                      " 显示行号
set ruler                    " 右下角显示光标位置的状态行
set incsearch                " 开启实时搜索功能
set hlsearch                 " 开启高亮显示结果
set nowrapscan               " 搜索到文件两端时不重新搜索
set nocompatible             " 关闭兼容模式
set hidden                   " 允许在有未保存的修改时切换缓冲区
set autochdir                " 设定文件浏览器目录为当前目录
set foldmethod=indent        " 选择代码折叠类型
set foldlevel=100            " 禁止自动折叠
set laststatus=2             " 开启状态栏信息
set cmdheight=2              " 命令行的高度，默认为1，这里设为2
set autoread                 " 当文件在外部被修改时自动更新该文件
set nobackup                 " 不生成备份文件
set noswapfile               " 不生成交换文件
set list                     " 显示特殊字符，其中Tab使用高亮~代替，尾部空白使用高亮点号代替
set listchars=tab:\~\ ,trail:.
set expandtab                " 将 Tab 自动转化成空格 [需要输入真正的 Tab 符时，使用 Ctrl+V + Tab]
"set showmatch               " 显示括号配对情况

" 使用 vimdiff 时，长行自动换行
autocmd FilterWritePre * if &diff | setlocal wrap< | endif

syntax enable                " 打开语法高亮
syntax on                    " 开启文件类型侦测
filetype indent off           " 针对不同的文件类型采用不同的缩进格式
filetype plugin off           " 针对不同的文件类型加载对应的插件
filetype plugin indent off    " 启用自动补全


" 设置文件编码和文件格式
set fenc=utf-8
set encoding=utf-8
set fileencodings=utf-8,gbk,cp936,latin-1
set fileformat=unix
set fileformats=unix,mac,dos
EOF
        export EDITOR=/usr/bin/vim
        echo 'set nu' >>~/.vimrc
        echo 'set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936' >>~/.vimrc
        echo 'set termencoding=utf-8' >>~/.vimrc
        echo 'set encoding=utf-8' >>~/.vimrc
        source ~/.bashrc
    fi
}

# install python
Install_Python() {
    green " "
    green " "
    green "================================="
    blue "  开始安装Python ${PYTHON_VERSION}..."
    green "================================="
    sleep 2s
    #获取本机python版本号。这里2>&1是必须的，python -V这个是标准错误输出的，需要转换
    # U_V1=$(python -V 2>&1 | awk '{print $2}' | awk -F '.' '{print $1}')
    # U_V2=$(python -V 2>&1 | awk '{print $2}' | awk -F '.' '{print $2}')
    # U_V3=$(python -V 2>&1 | awk '{print $2}' | awk -F '.' '{print $3}')
    #current_python_version=$U_V1.$U_V2.$U_V3

    if [ -e "${python_install_dir}/bin/python" ]; then
        current_python_version=$(${python_install_dir}/bin/python -V 2>&1 | awk '{print $2}')
        green "================================="
        red "  Python already installed! Python Version:${current_python_version}"
        green "================================="
    else
        pushd /opt >/dev/null
        if [ "${PM}" == 'yum' ]; then
            [ -z "$(grep -w epel /etc/yum.repos.d/*.repo)" ] && yum -y install epel-release
            pkgList="gcc dialog augeas-libs openssl openssl-devel libffi-devel redhat-rpm-config ca-certificates"
            for Package in ${pkgList}; do
                yum -y install ${Package}
            done
        elif [ "${PM}" == 'apt-get' ]; then
            pkgList="gcc dialog libaugeas0 augeas-lenses libssl-dev libffi-dev ca-certificates"
            for Package in ${pkgList}; do
                apt-get -y install $Package
            done
        fi

        # Install Python3
        if [ ! -e "${python_install_dir}/bin/python" -a ! -e "${python_install_dir}/bin/python3" ]; then
            # src_url=http://mirrors.linuxeye.com/oneinstack/src/Python-${python_ver}.tgz && Download_Src
            # wget --no-check-certificate -c https://mirrors.huaweicloud.com/python/${python3_ver}/Python-${python3_ver}.tgz

            # 注意：3.8.9文件名第一个字母P是大写的，3.9.0版本后为小写！
            src_url=https://npm.taobao.org/mirrors/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && Download_Src
            tar xzf Python-${PYTHON_VERSION}.tgz
            pushd Python-${PYTHON_VERSION} >/dev/null
            ./configure --prefix=${python_install_dir}
            make && make install
            [ ! -e "${python_install_dir}/bin/python" -a -e "${python_install_dir}/bin/python3" ] && ln -s ${python_install_dir}/bin/python{3,}
            [ ! -e "${python_install_dir}/bin/pip" -a -e "${python_install_dir}/bin/pip3" ] && ln -s ${python_install_dir}/bin/pip{3,}
            popd >/dev/null
        fi

        if [ ! -e "${python_install_dir}/bin/pip" ]; then
            src_url=http://mirrors.linuxeye.com/oneinstack/src/setuptools-${SETUPTOOLS_VERSION}.tar.gz && Download_Src
            src_url=http://mirrors.linuxeye.com/oneinstack/src/pip-${PIP_VERSION}.tar.gz && Download_Src
            tar xzf setuptools-${SETUPTOOLS_VERSION}.tar.gz
            tar xzf pip-${PIP_VERSION}.tar.gz
            pushd setuptools-${SETUPTOOLS_VERSION} >/dev/null
            ${python_install_dir}/bin/python setup.py install
            popd >/dev/null
            pushd pip-${PIP_VERSION} >/dev/null
            ${python_install_dir}/bin/python setup.py install
            popd >/dev/null
        fi

        if [ ! -e "/root/.pip/pip.conf" ]; then
            # get the IP information
            PUBLIC_IPADDR=$(../include/get_public_ipaddr.py)
            IPADDR_COUNTRY=$(../include/get_ipaddr_state.py ${PUBLIC_IPADDR})
            if [ "${IPADDR_COUNTRY}"x == "CN"x ]; then
                [ ! -d "/root/.pip" ] && mkdir /root/.pip
                #  pip国内的一些镜像
                #
                #  阿里云 http://mirrors.aliyun.com/pypi/simple/
                #  中国科技大学 https://pypi.mirrors.ustc.edu.cn/simple/
                #  豆瓣(douban) http://pypi.douban.com/simple/
                #  清华大学 https://pypi.tuna.tsinghua.edu.cn/simple/
                echo -e "[global]\nindex-url = http://mirrors.aliyun.com/pypi/simple/" >/root/.pip/pip.conf
                echo -e "extra-index-url= https://pypi.tuna.tsinghua.edu.cn/simple/" >>/root/.pip/pip.conf
                echo -e "\n[install]" >>/root/.pip/pip.conf
                echo -e "trusted-host=mirrors.aliyun.com" >>/root/.pip/pip.conf
            fi
        fi

        if [ -e "${python_install_dir}/bin/python3" ]; then
            green "================================="
            red "  Python ${python_ver} installed successfully!"
            green "================================="
            rm -rf /opt/Python-${python_ver}
        fi
        popd >/dev/null
    fi
}

# download method
Download_Src() {
    pushd /opt >/dev/null
    [ -s "${src_url##*/}" ] && echo "[${src_url##*/}] found" || {
        wget --limit-rate=10M -4 --tries=6 -c --no-check-certificate ${src_url}
        sleep 1
    }
    if [ ! -e "${src_url##*/}" ]; then
        echo "Auto download failed! You can manually download ${src_url} into the /opt directory."
        kill -9 $$
    fi
    popd >/dev/null
}

# Initialization system
Init_Os() {
    green " "
    green " "
    green "================================="
    blue "  Init System OS..."
    green "================================="
    sleep 2s
    cat >/etc/resolv.conf <<EOF
nameserver 114.114.114.114
nameserver 8.8.8.8
EOF

    if [ "${LikeOS}" == "CentOS" ]; then
        pkgList="net-tools libwebp-dev wget gcc curl usbutils nethogs iftop"
        for Package in ${pkgList}; do
            yum -y install $Package
        done
        init_centos
    elif [[ "${LikeOS}" =~ ^Ubuntu$|^Debian$ ]]; then
        if [ "${LikeOS}" == "Ubuntu" ]; then
            init_ubuntu
        elif [ "${LikeOS}" == "Debian" ]; then
            init_debian
        fi

        pkgList="net-tools gcc dialog libaugeas0 augeas-lenses libssl-dev libffi-dev ca-certificates g++ make cmake autoconf \
                zlib1g zlib1g-dev libc6 libc6-dev libglib2.0-0 libglib2.0-dev build-essential libpam0g-dev \
                bzip2 libzip-dev libbz2-1.0 libncurses5 libncurses5-dev libaio1 libaio-dev numactl libreadline-dev curl libcurl3 \
                libcurl4-openssl-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn11 libidn11-dev libssl-dev libtool \
                libevent-dev re2c libsasl2-dev libxslt1-dev libicu-dev libsqlite3-dev patch htop bc dc expect \
                libexpat1-dev rsyslog rsync lsof lrzsz ntpdate wget sysv-rc gettext unzip cwebp usbutils nethogs iftop"
        for Package in ${pkgList}; do
            apt-get -y install $Package
        done
    else
        red "================================="
        red "  init_os，current os not support"
        red "================================="
        sleep 2s
    fi

    touch /var/run/init-lock
}

init_common_settings() {
    green " "
    green " "
    green "================================="
    blue "  Init Common Settings ..."
    green "================================="
    sleep 2s
    # /etc/hosts
    [ "$(hostname -i | awk '{print $1}')" != "127.0.0.1" ] && sed -i "s@127.0.0.1.*localhost@&\n127.0.0.1 $(hostname)@g" /etc/hosts

    # Set timezone
    timedatectl set-timezone ${timezone}
    rm -fr /etc/localtime
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    localectl set-locale LC_TIME=en_GB.UTF-8

    # Set DNS
    #cat > /etc/resolv.conf << EOF
    #nameserver 114.114.114.114
    #nameserver 8.8.8.8
    #EOF

    # Update time
    if [ -e "$(which ntpdate)" ]; then
        ntpdate -u pool.ntp.org
        [ ! -e "/var/spool/cron/crontabs/root" -o -z "$(grep ntpdate /var/spool/cron/crontabs/root 2>/dev/null)" ] && {
            echo "*/20 * * * * $(which ntpdate) -u pool.ntp.org > /dev/null 2>&1" >>/var/spool/cron/crontabs/root
            chmod 600 /var/spool/cron/crontabs/root
        }
    fi

    # Custom profile
    if [ ! -f /etc/profile.d/oneinstack.sh ]; then
        cat >/etc/profile.d/oneinstack.sh <<EOF
HISTSIZE=10000
HISTTIMEFORMAT="%F %T \$(whoami) "

alias l='ls -AFhlt --color=auto'
alias lh='l | head'
alias ll='ls -l --color=auto'
alias ls='ls --color=auto'
alias vi=vim
alias h='history'
alias hc='history -c'

GREP_OPTIONS="--color=auto"
alias grep='grep --color'
alias egrep='egrep --color'
alias fgrep='fgrep --color'
EOF
        if [ "${LikeOS}" == "CentOS" ]; then
            echo 'PS1="\[\e[37;40m\][\[\e[32;40m\]\u\[\e[37;40m\]@\h \[\e[35;40m\]\W\[\e[0m\]]\\\\$ "' >>/etc/profile.d/oneinstack.sh
            [[ "${OS}" =~ ^EulerOS$|^openEuler$ ]] && sed -i '/HISTTIMEFORMAT=/d' /etc/profile.d/oneinstack.sh
        elif [ "${LikeOS}" == "Debian" ]; then
            echo "PS1='\${debian_chroot:+(\$debian_chroot)}\\[\\e[1;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '" >>/etc/profile.d/oneinstack.sh
        else
            red "================================="
            red "  init_os，current os not support."
            red "================================="
        fi
    fi
}

init_centos() {
    green " "
    green " "
    green "================================="
    blue "  Init CentOS ..."
    green "================================="
    sleep 2s

    # Close SELINUX
    setenforce 0
    sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config

    init_common_settings

    [[ ! "${OS}" =~ ^EulerOS$|^openEuler$ ]] && [ -z "$(grep ^'PROMPT_COMMAND=' /etc/bashrc)" ] && cat >>/etc/bashrc <<EOF
PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });logger "[euid=\$(whoami)]":\$(who am i):[\`pwd\`]"\$msg"; }'
EOF

    # /etc/security/limits.conf
    [ -e /etc/security/limits.d/*nproc.conf ] && rename nproc.conf nproc.conf_bk /etc/security/limits.d/*nproc.conf
    sed -i '/^# End of file/,$d' /etc/security/limits.conf
    cat >>/etc/security/limits.conf <<EOF
# End of file
* soft nproc 1000000
* hard nproc 1000000
* soft nofile 1000000
* hard nofile 1000000
EOF

    # ip_conntrack table full dropping packets
    [ ! -e "/etc/sysconfig/modules/iptables.modules" ] && {
        echo -e "modprobe nf_conntrack\nmodprobe nf_conntrack_ipv4" >/etc/sysconfig/modules/iptables.modules
        chmod +x /etc/sysconfig/modules/iptables.modules
    }
    modprobe nf_conntrack
    modprobe nf_conntrack_ipv4
    echo options nf_conntrack hashsize=131072 >/etc/modprobe.d/nf_conntrack.conf

    # /etc/sysctl.conf
    [ ! -e "/etc/sysctl.conf_bk" ] && /bin/mv /etc/sysctl.conf{,_bk}
    cat >/etc/sysctl.conf <<EOF
fs.file-max=1000000
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 16384 4194304
net.ipv4.tcp_max_syn_backlog = 16384
net.core.netdev_max_backlog = 32768
net.core.somaxconn = 32768
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_syncookies = 1
#net.ipv4.tcp_tw_len = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.ip_local_port_range = 1024 65000
net.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_established = 3600
EOF
    sysctl -p

    if [ "${CentOS_ver}" == '6' ]; then
        sed -i 's@^ACTIVE_CONSOLES.*@ACTIVE_CONSOLES=/dev/tty[1-2]@' /etc/sysconfig/init
        sed -i 's@^start@#start@' /etc/init/control-alt-delete.conf
        sed -i 's@LANG=.*$@LANG="en_US.UTF-8"@g' /etc/sysconfig/i18n
    elif [ ${CentOS_ver} -ge 7 ] >/dev/null 2>&1; then
        sed -i 's@LANG=.*$@LANG="en_US.UTF-8"@g' /etc/locale.conf
    fi

    # iptables
    if [ "${iptables_flag}" == 'y' ]; then
        if [ -e "/etc/sysconfig/iptables" ] && [ -n "$(grep '^:INPUT DROP' /etc/sysconfig/iptables)" -a -n "$(grep 'NEW -m tcp --dport 22 -j ACCEPT' /etc/sysconfig/iptables)" -a -n "$(grep 'NEW -m tcp --dport 80 -j ACCEPT' /etc/sysconfig/iptables)" ]; then
            IPTABLES_STATUS=yes
        else
            IPTABLES_STATUS=no
        fi

        if [ "$IPTABLES_STATUS" == "no" ]; then
            [ -e "/etc/sysconfig/iptables" ] && /bin/mv /etc/sysconfig/iptables{,_bk}
            cat >/etc/sysconfig/iptables <<EOF
# Firewall configuration written by system-config-securitylevel
# Manual customization of this file is not recommended.
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:syn-flood - [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
COMMIT
EOF
        fi

        FW_PORT_FLAG=$(grep -ow "dport ${ssh_port}" /etc/sysconfig/iptables)
        [ -z "${FW_PORT_FLAG}" -a "${ssh_port}" != "22" ] && sed -i "s@dport 22 -j ACCEPT@&\n-A INPUT -p tcp -m state --state NEW -m tcp --dport ${ssh_port} -j ACCEPT@" /etc/sysconfig/iptables
        /bin/cp /etc/sysconfig/{iptables,ip6tables}
        sed -i 's@icmp@icmpv6@g' /etc/sysconfig/ip6tables
        iptables-restore </etc/sysconfig/iptables
        ip6tables-restore </etc/sysconfig/ip6tables
        service iptables save
        service ip6tables save
        chkconfig --level 3 iptables on
        chkconfig --level 3 ip6tables on
    fi
    service rsyslog restart
    service sshd restart

    . /etc/profile
}

function init_ubuntu() {
    green " "
    green " "
    green "================================="
    blue "  Init Ubuntu ..."
    green "================================="
    sleep 2s

    init_common_settings

    sed -i 's@^"syntax on@syntax on@' /etc/vim/vimrc

    # PS1
    [ -z "$(grep ^PS1 ~/.bashrc)" ] && echo "PS1='\${debian_chroot:+(\$debian_chroot)}\\[\\e[1;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '" >>~/.bashrc

    # history
    [ -z "$(grep history-timestamp ~/.bashrc)" ] && echo "PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });user=\$(whoami); echo \$(date \"+%Y-%m-%d %H:%M:%S\"):\$user:\`pwd\`/:\$msg ---- \$(who am i); } >> /tmp/\`hostname\`.\`whoami\`.history-timestamp'" >>~/.bashrc

    # /etc/security/limits.conf
    [ -e /etc/security/limits.d/*nproc.conf ] && rename nproc.conf nproc.conf_bk /etc/security/limits.d/*nproc.conf
    [ -z "$(grep 'session required pam_limits.so' /etc/pam.d/common-session)" ] && echo "session required pam_limits.so" >>/etc/pam.d/common-session
    sed -i '/^# End of file/,$d' /etc/security/limits.conf
    cat >>/etc/security/limits.conf <<EOF
# End of file
* soft nproc 1000000
* hard nproc 1000000
* soft nofile 1000000
* hard nofile 1000000
root soft nproc 1000000
root hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF

    # /etc/sysctl.conf
    [ -z "$(grep 'fs.file-max' /etc/sysctl.conf)" ] && cat >>/etc/sysctl.conf <<EOF
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
EOF
    sysctl -p

    sed -i 's@^ACTIVE_CONSOLES.*@ACTIVE_CONSOLES="/dev/tty[1-2]"@' /etc/default/console-setup
    locale-gen en_US.UTF-8
    [ -d "/var/lib/locales/supported.d" ] && echo "en_US.UTF-8 UTF-8" >/var/lib/locales/supported.d/local
    cat >/etc/default/locale <<EOF
LANG=en_US.UTF-8
LANGUAGE=en_US:en
EOF

    Set_Firewall

    # iptables
    if [ "${iptables_flag}" == 'y' ]; then

    fi
    service rsyslog restart
    service ssh restart

    . /etc/profile
    . ~/.bashrc

}

function init_debian() {
    green " "
    green " "
    green "================================="
    blue "  Init Debian ..."
    green "================================="
    sleep 2s

    init_common_settings

    sed -i 's@^"syntax on@syntax on@' /etc/vim/vimrc

    # history
    [ -z "$(grep history-timestamp ~/.bashrc)" ] && echo "PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });user=\$(whoami); echo \$(date \"+%Y-%m-%d %H:%M:%S\"):\$user:\`pwd\`/:\$msg ---- \$(who am i); } >> /tmp/\`hostname\`.\`whoami\`.history-timestamp'" >>~/.bashrc

    # /etc/security/limits.conf
    [ -e /etc/security/limits.d/*nproc.conf ] && rename nproc.conf nproc.conf_bk /etc/security/limits.d/*nproc.conf
    [ -z "$(grep 'session required pam_limits.so' /etc/pam.d/common-session)" ] && echo "session required pam_limits.so" >>/etc/pam.d/common-session
    sed -i '/^# End of file/,$d' /etc/security/limits.conf
    cat >>/etc/security/limits.conf <<EOF
# End of file
* soft nproc 1000000
* hard nproc 1000000
* soft nofile 1000000
* hard nofile 1000000
root soft nproc 1000000
root hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF

    # /etc/sysctl.conf
    [ -z "$(grep 'fs.file-max' /etc/sysctl.conf)" ] && cat >>/etc/sysctl.conf <<EOF
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
EOF
    sysctl -p

    sed -i 's@^ACTIVE_CONSOLES.*@ACTIVE_CONSOLES="/dev/tty[1-2]"@' /etc/default/console-setup
    sed -i 's@^# en_US.UTF-8@en_US.UTF-8@' /etc/locale.gen
    init q

    # nftables
    apt remove iptables ufw
    apt install nftables

    Set_Firewall
    systemctl restart rsyslog.service
    systemctl restart ssh.service

    . /etc/profile
    . ~/.bashrc

}

Set_Firewall() {
    green " "
    green " "
    green "================================="
    blue "  Set Firewall ..."
    green "================================="
    sleep 2s

    sshPort=$(cat /etc/ssh/sshd_config | grep 'Port ' | awk '{print $2}')
    if [ "${PM}" = "apt-get" ]; then
        apt-get install -y ufw
        if [ -f "/usr/sbin/ufw" ]; then
            ufw allow 20/tcp
            ufw allow 21/tcp
            ufw allow 22/tcp
            ufw allow 80/tcp
            ufw allow 888/tcp
            ufw allow ${sshPort}/tcp
            ufw allow 39000:40000/tcp
            ufw_status=$(ufw status)
            echo y | ufw enable
            ufw default deny
            ufw reload
        fi
        if [ -f "/usr/sbin/nft" ]; then
            # 清空当前规则集：
            nft flush ruleset
            nft add table inet filter
            nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
            nft add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
            nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }
            nft add chain inet filter TCP
            nft add chain inet filter UDP
            nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
            nft add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
            nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }
            nft add chain inet filter TCP
            nft add chain inet filter UDP
            nft add map inet filter input_vmap \{ type inet_proto : verdict \; \}
            nft add element inet filter input_vmap \{ tcp : jump TCP, udp : jump UDP \}
            nft add rule inet filter input meta l4proto vmap @input_vmap
            nft add rule inet filter input ct state \{ established, related \} counter accept comment \"Accept traffic originated from us\"
            nft add rule inet filter input ct state invalid drop
            nft add rule inet filter input iif "lo" accept comment \"Accept any localhost traffic\"
            nft add rule inet filter input iif != "lo" ip daddr 127.0.0.0/8 counter drop comment \"drop connections to loopback not coming from loopback\"
            nft add rule inet filter input ip protocol icmp icmp type echo-request ct state new accept
            nft add rule inet filter input ip protocol icmp icmp type echo-request drop comment \"No ping floods\"
            nft add rule inet filter input ip protocol icmp icmp type echo-request limit rate 20 bytes/second burst 500 bytes counter accept comment \"No ping floods\"
            nft add rule inet filter input ip protocol udp ct state new jump UDP
            nft add rule inet filter input ip protocol tcp tcp flags \& \(fin\|syn\|rst\|ack\) == syn ct state new jump TCP
            nft add rule inet filter input ip protocol udp reject
            nft add rule inet filter input ip protocol tcp reject with tcp reset
            nft add rule inet filter input counter reject with icmp type prot-unreachable
            nft add rule inet filter TCP tcp dport 22 accept
            nft add set inet filter web \{ type inet_service \; flags interval \; \}
            nft add element inet filter web \{ 80, 88, 443 \}
            nft add rule inet filter TCP tcp dport @web counter accept comment \"Accept web server\"
            nft add set inet filter db \{ type inet_service \; flags interval \; \}
            nft add element inet filter db \{ 3306, 6379, 27017 \}
            nft add rule inet filter TCP tcp dport @db counter accept comment \"Accept database server\"
            nft add set inet filter other \{ type inet_service \; flags interval \; \}
            nft add element inet filter other \{ 21, 990, 20000-30000, 1701 \}
            nft add rule inet filter TCP tcp dport @other counter accept comment \"Accept other service\"
            nft add set inet filter other \{ type inet_service \; flags interval \; \}
            nft add element inet filter other \{ 4500, 500 \}
            nft add rule inet filter UDP udp dport @other counter accept comment \"Accept udp service\"
            nft add rule inet filter input ct state invalid log prefix \"Invalid-Input: \" level info flags all counter drop comment \"Drop invalid connections\"
            nft add rule inet filter input ip protocol icmp icmp type \{ destination-unreachable, router-advertisement, router-solicitation, time-exceeded, parameter-problem \} accept comment \"Accept ICMP\"
            nft add rule inet filter input ip protocol igmp accept comment \"Accept IGMP\"

            nft list ruleset >/etc/nftables.conf

            systemctl enable nftables.service
            systemctl restart nftables.service
        fi
    else
        if [ -f "/etc/init.d/iptables" ]; then
            iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 20 -j ACCEPT
            iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 21 -j ACCEPT
            iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
            iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
            iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 20000:30000 -j ACCEPT
            #iptables -I INPUT -p tcp -m state --state NEW -m udp --dport 39000:40000 -j ACCEPT
            iptables -A INPUT -p icmp --icmp-type any -j ACCEPT
            iptables -A INPUT -s localhost -d localhost -j ACCEPT
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -P INPUT DROP
            service iptables save
            sed -i "s#IPTABLES_MODULES=\"\"#IPTABLES_MODULES=\"ip_conntrack_netbios_ns ip_conntrack_ftp ip_nat_ftp\"#" /etc/sysconfig/iptables-config
            iptables_status=$(service iptables status | grep 'not running')

            FW_PORT_FLAG=$(grep -ow "dport ${sshPort}" /etc/iptables/rules.v4)
            [ -z "${FW_PORT_FLAG}" -a "${sshPort}" != "22" ] && sed -i "s@dport 22 -j ACCEPT@&\n-A INPUT -p tcp -m state --state NEW -m tcp --dport ${sshPort} -j ACCEPT@" /etc/iptables/rules.v4
            iptables-restore </etc/iptables/rules.v4
            /bin/cp /etc/iptables/rules.v{4,6}
            sed -i 's@icmp@icmpv6@g' /etc/iptables/rules.v6
            ip6tables-restore </etc/iptables/rules.v6
            ip6tables-save >/etc/iptables/rules.v6

            if [ "${iptables_status}" == '' ]; then
                service iptables restart
            fi

        else
            [ "${AliyunCheck}" ] && return
            yum install firewalld -y
            [ "${Centos8Check}" ] && yum reinstall python3-six -y
            systemctl enable firewalld
            systemctl start firewalld
            firewall-cmd --set-default-zone=public >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=20/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=21/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=22/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=80/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=${sshPort}/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=39000-40000/tcp >/dev/null 2>&1
            #firewall-cmd --permanent --zone=public --add-port=39000-40000/udp > /dev/null 2>&1
            firewall-cmd --reload
        fi
    fi
}

Start_Up() {
    startTime=$(date "+%Y-%m-%d %H:%M:%S")
    startTime_s=$(date +%s)

    # 添加终端字符画
    wget https://gitee.com/indextank/z7z8/raw/master/motd -O motd && mv -f motd /etc/

    Check_Os

    # 文件不存在，代表第一次执行，如果存在则跳过，节省时间
    # 如果想跳过，也可以手动创建一个该文件，第一次建议执行，否则会缺少众多依赖。
    if [ ! -f /tmp/init-lock ]; then
        Init_Os
    fi

    Install_Openssl
    Install_Git
    Install_Vim
    Install_Composer
    #Install_Php_Assist
    Install_Python

    endTime=$(date "+%Y-%m-%d %H:%M:%S")
    endTime_s=$(date +%s)
    sumTime=$(($endTime_s - $startTime_s))
    echo -e "\n\n===========================================\nFinished!\n\n开始时间：$startTime \n结束时间：$endTime \n总耗时: $sumTime minutes\n==========================================="
}

Start_Up
