
module(..., package.seeall)

local sorttable = require"sputnik.javascript.sorttable"
local wiki = require("sputnik.actions.wiki")
local util = require("sputnik.util")

actions = {}

local function format_list(nodes, template, sputnik, node)
   return util.f(template){
            new_url = sputnik:make_url(node.id.."/new", "edit"),
            id      = node.id,
            do_nodes = function()
                          for i, node in ipairs(nodes) do
                             local t = {
                                url = sputnik.config.NICE_URL..node.id,
                                id  = node.id,
                             }
                             for k, v in pairs(node.fields) do
                                 t[k] = tostring(node[k])
                             end
                             cosmo.yield (t)
                          end
            end,
         }
end

function actions.list_children(node, request, sputnik)
   node:add_javascript_snippet(sorttable.script)
   local nodes = wiki.get_visible_nodes(sputnik, request.user, node.id.."/")
   node.inner_html = format_list(nodes, node.content_template, sputnik, node)
   return node.wrappers.default(node, request, sputnik)
end

function actions.list_children_as_xml(node, request, sputnik)
   local nodes = wiki.get_visible_nodes(sputnik, request.user, node.id.."/")
   return format_list(nodes, node.xml_template, sputnik, node), "text/xml"
end

local PARENT_PATTERN = "(.+)%/[^%/]+$" -- everything up to the last slash

actions.save_new = function(node, request, sputnik)
   local parent_id = node.id:match(PARENT_PATTERN)
   local parent = sputnik:get_node(parent_id)
   local new_id = string.format("%s/%06d", parent_id, sputnik:get_uid(parent_id))
   local new_node = sputnik:get_node(new_id)
   sputnik:update_node_with_params(new_node, {prototype = parent.child_proto})
   new_node = sputnik:activate_node(new_node)
   new_node.inner_html = "Created a new item: <a "..sputnik:make_link(new_id)..">"
                         ..new_id.."</a><br/>"
                         .."List <a "..sputnik:make_link(parent_id)..">items</a>"
   return wiki.actions.save(new_node, request, sputnik)
end

function actions.rss(node, request, sputnik)
   local title = "Recent Additions to '" .. node.title .."'"  --::LOCALIZE::--
   local edits = sputnik:get_history(node.name, 50)

   local items = wiki.get_visible_nodes(sputnik, request.user, node.id.."/")
   table.sort(items, function(x,y) return x.id > y.id end )

   return cosmo.f(node.templates.RSS){  
      title   = title,
      baseurl = sputnik.config.BASE_URL, 
      items   = function()
                   for i, item in ipairs(items) do
                         cosmo.yield{
                            link        = "http://" .. sputnik.config.DOMAIN ..
                                          sputnik:escape_url(sputnik:make_url(item.id)),
                            title       = item.title,
                            ispermalink = "false",
                            guid        = item.id,
                            summary     = item.content,
                         }
                   end
                end,
   }, "application/rss+xml"
end
