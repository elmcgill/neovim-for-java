local M = {}

function M.setup()
    local function get_jdtls()
        local mason_registry = require "mason-registry"
        local jdtls = mason_registry.get_package "jdtls"
        local jdtls_path = jdtls:get_install_path()
        local launcher = vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar")
        local SYSTEM = "linux"
        local config = jdtls_path .. "/config_" .. SYSTEM
        local lombok = jdtls_path .. "/lombok.jar"
      return launcher, config, lombok
    end
    -- get_jdtls()
   
    local function get_bundles()
        local mason_registry = require "mason-registry"
        local java_debug = mason_registry.get_package "java-debug-adapter"
        local java_test = mason_registry.get_package "java-test"
        local java_debug_path = java_debug:get_install_path()
        local java_test_path = java_test:get_install_path()
        local bundles = {}
        vim.list_extend(bundles, vim.split(vim.fn.glob(java_debug_path .. "/extension/server/com.microsoft.java.debug.plugin-*.jar"), "\n"))
        vim.list_extend(bundles, vim.split(vim.fn.glob(java_test_path .. "/extension/server/*.jar"), "\n"))
        return bundles
    end
    -- get_bundles()
   
    local function get_workspace()
        local home = os.getenv "HOME"
        local workspace_path = home .. "/code/workspace/"
        local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
        local workspace_dir = workspace_path .. project_name
        return workspace_dir
    end
    -- print(get_workspace())


    local jdtls = require "jdtls"
    local jdtls_setup = require("jdtls.setup")
    local capabilities = {
        workspace = {
            configuration = true
        },
        textDocument = {
            completion = {
                completionItem = {
                    snippetSupport = false
                }
            }
        }
    }
    local extendedClientCapabilities = jdtls.extendedClientCapabilities
    extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

    local launcher, os_config, lombok = get_jdtls()
    local workspace_dir = get_workspace()
    local bundles = get_bundles()

    local on_attach = function(_, bufnr)
        vim.lsp.codelens.refresh()
        jdtls.setup_dap { hotcodereplace = "auto"}
        require("jdtls.dap").setup_dap_main_class_configs()
        require("jdtls.setup").add_commands()
        
        local lsp_keymaps = function()
            vim.cmd(
              "command! -buffer -nargs=? -complete=custom,v:lua.require'jdtls'._complete_compile JdtCompile lua require('jdtls').compile(<f-args>)"
            )
            vim.cmd(
              "command! -buffer -nargs=? -complete=custom,v:lua.require'jdtls'._complete_set_runtime JdtSetRuntime lua require('jdtls').set_runtime(<f-args>)"
            )
            vim.cmd("command! -buffer JdtUpdateConfig lua require('jdtls').update_project_config()")
            vim.cmd("command! -buffer JdtJol lua require('jdtls').jol()")
            vim.cmd("command! -buffer JdtBytecode lua require('jdtls').javap()")
            vim.cmd("command! -buffer JdtJshell lua require('jdtls').jshell()")

            local status_ok, which_key = pcall(require, "which-key")
            if not status_ok then
              return
            end

            local opts = {
              mode = "n",     -- NORMAL mode
              prefix = "<leader>",
              buffer = nil,   -- Global mappings. Specify a buffer number for buffer local mappings
              silent = true,  -- use `silent` when creating keymaps
              noremap = true, -- use `noremap` when creating keymaps
              nowait = true,  -- use `nowait` when creating keymaps
            }

            local vopts = {
              mode = "v",     -- VISUAL mode
              prefix = "<leader>",
              buffer = nil,   -- Global mappings. Specify a buffer number for buffer local mappings
              silent = true,  -- use `silent` when creating keymaps
              noremap = true, -- use `noremap` when creating keymaps
              nowait = true,  -- use `nowait` when creating keymaps
            }

            local mappings = {
              J = {
                name = "Java",
                o = { "<Cmd>lua require'jdtls'.organize_imports()<CR>", "Organize Imports" },
                v = { "<Cmd>lua require('jdtls').extract_variable()<CR>", "Extract Variable" },
                c = { "<Cmd>lua require('jdtls').extract_constant()<CR>", "Extract Constant" },
                t = { "<Cmd>lua require'jdtls'.test_nearest_method()<CR>", "Test Method" },
                T = { "<Cmd>lua require'jdtls'.test_class()<CR>", "Test Class" },
                u = { "<Cmd>JdtUpdateConfig<CR>", "Update Config" },
              },
            }

            local vmappings = {
              J = {
                name = "Java",
                v = { "<Esc><Cmd>lua require('jdtls').extract_variable(true)<CR>", "Extract Variable" },
                c = { "<Esc><Cmd>lua require('jdtls').extract_constant(true)<CR>", "Extract Constant" },
                m = { "<Esc><Cmd>lua require('jdtls').extract_method(true)<CR>", "Extract Method" },
              },
            }

        which_key.register(mappings, opts)
        end
        
        lsp_keymaps()

        vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = {"*.java"},
            callback = function()
                local _, _ = pcall(vim.lsp.codelens.refresh)
            end,
        })
    end
    local root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }
    local root_dir = jdtls_setup.find_root(root_markers)

    local config = {
        cmd = {
          "java",
          "-Declipse.application=org.eclipse.jdt.ls.core.id1",
          "-Dosgi.bundles.defaultStartLevel=4",
          "-Declipse.product=org.eclipse.jdt.ls.core.product",
          "-Dlog.protocol=true",
          "-Dlog.level=ALL",
          "-Xms1g",
          "--add-modules=ALL-SYSTEM",
          "--add-opens",
          "java.base/java.util=ALL-UNNAMED",
          "--add-opens",
          "java.base/java.lang=ALL-UNNAMED",
          "-javaagent:" .. lombok,
          "-jar",
          launcher,
          "-configuration",
          os_config,
          "-data",
          workspace_dir,
        },
        root_dir = root_dir,
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
            java = {
                autobuild = {enabled = false},
                format = {
                    enabled = true,
                    settings = {
                        url = vim.fn.stdpath("config")  .. "/lang_servers/intellij-java-google-style.xml",
                        profile = "GoogleStyle"
                    }
                },
                eclipse = {
                    downloadSource = true
                },
                maven = {
                    downloadSources = true
                },
                signatureHelp = {
                    enabled = true
                },
                contentProvider = {
                    preferred = "fernflower"
                },
                saveActions = {
                    organizeImports = true
                },
                completion = {
                    favoriteStaticMembers = {
                        "org.hamcrest.MatcherAssert.assertThat",
                        "org.hamcrest.Matchers.*",
                        "org.hamcrest.CoreMatchers.*",
                        "org.junit.jupiter.api.Assertions.*",
                        "java.util.Objects.requireNonNull",
                        "java.util.Objects.requireNonNullElse",
                        "org.mockito.Mockito.*",
                    },
                    filteredTypes = {
                        "com.sun.*",
                        "io.micrometer.shaded.*",
                        "java.awt.*",
                        "jdk.*",
                        "sun.*",
                    },
                    importOrder = {
                        "java",
                        "javax",
                        "com",
                        "org",
                    }
                },
                sources = {
                    organizeImports = {
                        starThreshold = 9999,
                        staticThreshold = 9999
                    }
                },
                codeGeneration = {
                    toString = {
                        template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}"
                    },
                    hashCodeEquals = {
                        useJava7Objects = true
                    },
                    useBlocks = true
                },
                configuration = {
                    updateBuildConfiguration = "interactive"
                },
                implentationCodeLens = {
                    enabled = true
                },
                referencesCodeLens = {
                    enabled = true
                },
                inlayHints = {
                    parameterNames = {
                        enabled = "all"
                    }
                }
            }
        },
        init_options = {
            bundles = bundles,
            extendedClientCapabilities = extendedClientCapabilities
        }
    }

    require("jdtls").start_or_attach(config);
end
return M

    --[[
    local jdtls = require("jdtls")
    local jdtls_dap = require("jdtls.dap")
    local java_test = require("java-test")
    local java_debug_adapter = require("java-debug-adapter")
    local jdtls_setup = require("jdtls.setup")
    local home = os.getenv("HOME")

    local root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }
    local root_dir = jdtls_setup.find_root(root_markers)

    local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
    local workspace_dir = home .. "/.cache/jdtls/workspace/" .. project_name

    local path_to_mason_packages = home .. "/.local/share/nvim/mason/packages"
    local path_to_jdtls = path_to_mason_packages .. "/jdtls"
    local path_to_jdebug = path_to_mason_packages .. "/java-debug-adapter"
    local path_to_jtest = path_to_mason_packages .. "/java-test"

    local path_to_config = path_to_jdtls .. "/config_linux"
    local lombok_path = path_to_jdtls .. "/lombok.jar"

    local path_to_jar = path_to_jdtls .. "/plugins/org.eclipse.equinox.launcher_1.6.700.v20231214-2017.jar"
    
    local bundles = {
        vim.fn.glob(path_to_jdebug .. "/extension/server/com.microsoft.java.debug.plugin-*.jar", true),
    }

    vim.list_extend(bundles, vim.split(vim.fn.glob(path_to_jtest .. "/extension/server/*.jar", true), "\n"))
    
    local lsp_keymaps = function()
        vim.cmd(
          "command! -buffer -nargs=? -complete=custom,v:lua.require'jdtls'._complete_compile JdtCompile lua require('jdtls').compile(<f-args>)"
        )
        vim.cmd(
          "command! -buffer -nargs=? -complete=custom,v:lua.require'jdtls'._complete_set_runtime JdtSetRuntime lua require('jdtls').set_runtime(<f-args>)"
        )
        vim.cmd("command! -buffer JdtUpdateConfig lua require('jdtls').update_project_config()")
        vim.cmd("command! -buffer JdtJol lua require('jdtls').jol()")
        vim.cmd("command! -buffer JdtBytecode lua require('jdtls').javap()")
        vim.cmd("command! -buffer JdtJshell lua require('jdtls').jshell()")

        local status_ok, which_key = pcall(require, "which-key")
        if not status_ok then
          return
        end

        local opts = {
          mode = "n",     -- NORMAL mode
          prefix = "<leader>",
          buffer = nil,   -- Global mappings. Specify a buffer number for buffer local mappings
          silent = true,  -- use `silent` when creating keymaps
          noremap = true, -- use `noremap` when creating keymaps
          nowait = true,  -- use `nowait` when creating keymaps
        }

        local vopts = {
          mode = "v",     -- VISUAL mode
          prefix = "<leader>",
          buffer = nil,   -- Global mappings. Specify a buffer number for buffer local mappings
          silent = true,  -- use `silent` when creating keymaps
          noremap = true, -- use `noremap` when creating keymaps
          nowait = true,  -- use `nowait` when creating keymaps
        }

        local mappings = {
          J = {
            name = "Java",
            o = { "<Cmd>lua require'jdtls'.organize_imports()<CR>", "Organize Imports" },
            v = { "<Cmd>lua require('jdtls').extract_variable()<CR>", "Extract Variable" },
            c = { "<Cmd>lua require('jdtls').extract_constant()<CR>", "Extract Constant" },
            t = { "<Cmd>lua require'jdtls'.test_nearest_method()<CR>", "Test Method" },
            T = { "<Cmd>lua require'jdtls'.test_class()<CR>", "Test Class" },
            u = { "<Cmd>JdtUpdateConfig<CR>", "Update Config" },
          },
        }

        local vmappings = {
          J = {
            name = "Java",
            v = { "<Esc><Cmd>lua require('jdtls').extract_variable(true)<CR>", "Extract Variable" },
            c = { "<Esc><Cmd>lua require('jdtls').extract_constant(true)<CR>", "Extract Constant" },
            m = { "<Esc><Cmd>lua require('jdtls').extract_method(true)<CR>", "Extract Method" },
          },
        }

        which_key.register(mappings, opts)
        which_key.register(vmappings, vopts)

    end

    local on_attach = function(_, bufnr)
        jdtls.setup_dap({ hotcodereplace = "auto" })
        jdtls_dap.setup_dap_main_class_configs()
        jdtls_setup.add_commands()
        lsp_keymaps()

        -- Create a command `:Format` local to the LSP buffer
        vim.api.nvim_buf_create_user_command(bufnr, "Format", function(_)
            vim.lsp.buf.format()
        end, { desc = "Format current buffer with LSP" })

        require("lsp_signature").on_attach({
            bind = true,
            padding = "",
            handler_opts = {
                border = "rounded"
            },
            hint_prefix = "󱄑 "
        }, bufnr)
    end

    local capabilities = {
        workspace = {
            configuration = true
        },
        textDocument = {
            completion = {
                completionItem = {
                    snippetSupport = true
                }
            }
        }
    }

    local config = {
        flags = {
            allow_incremental_sync = true
        }
    }

    config.cmd = {
        "/usr/lib/jvm/java-17-openjdk-amd64/bin/java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xmx1g",
        "-javaagent:" .. lombok_path,
        "--add-modules=ALL-SYSTEM",
        "--add-opens",
        "java.base/java.util=ALL-UNNAMED",
        "--add-opens",
        "java.base/java.lang=ALL-UNNAMED",
        "-jar",
        path_to_jar,
        "-configuration",
        path_to_config,
        "-data",
        workspace_dir,
    }
    
    config.settings = {
        java = {
            references = {
                includeDecompiledSources = true,
            },
            format = {
                enabled = true,
                settings = {
                    url = vim.fn.stdpath("config")  .. "/lang_servers/intellij-java-google-style.xml",
                    profile = "GoogleStyle"
                }
            },
            eclipse = {
                downloadSource = true
            },
            maven = {
                downloadSources = true
            },
            signatureHelp = {
                enabled = true
            },
            contentProvider = {
                preferred = "fernflower"
            },
            completion = {
                favoriteStaticMembers = {
                    "org.hamcrest.MatcherAssert.assertThat",
                    "org.hamcrest.Matchers.*",
                    "org.hamcrest.CoreMatchers.*",
                    "org.junit.jupiter.api.Assertions.*",
                    "java.util.Objects.requireNonNull",
                    "java.util.Objects.requireNonNullElse",
                    "org.mockito.Mockito.*",
                },
                filteredTypes = {
                    "com.sun.*",
                    "io.micrometer.shaded.*",
                    "java.awt.*",
                    "jdk.*",
                    "sun.*",
                },
                importOrder = {
                    "java",
                    "javax",
                    "com",
                    "org",
                }
            },
            sources = {
                organizeImports = {
                    starThreshold = 9999,
                    staticThreshold = 9999
                }
            },
            codeGeneration = {
                toString = {
                    template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}"
                },
                useBlocks = true
            },
        }
    }
    
    config.on_attach = on_attach
    config.capabilities = capabilities
    config.on_init = function(client, _)
        client.notify('workspace/didChangeConfiguration', { settings = config.settings })
    end

    local extendedClientCapabilities = require 'jdtls'.extendedClientCapabilities
    extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

    config.init_options = {
        bundles = bundles,
        extendedClientCapabilities = extendedClientCapabilities,
    }

    -- Start Server
    require('jdtls').start_or_attach(config)

  
--]]

