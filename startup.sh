# echoerr "Starting a ${k}-node network."

# for ((i=1; i<=k; i++)); do
#   generate_config_file $i "$spr"
#   start_node $i "${import_folder}"

#   if [ $i -eq 1 ]; then
#     echoerr "Wait for bootstrap SPR."
#     spr=$(await 10 get_spr $i)
#     echoerr "SPR is: ${spr}"
#   fi

#   if [ -n "${import_folder}" ]; then
#     echoerr "Populate node $i with files from ${import_folder}."
#     #shellcheck disable=SC2012
#     await 10 cid_count_ge $i "$(ls -1 "${import_folder}" 2> /dev/null | wc -l)"

#     echoerr "CIDs for node $i:"
#     get_cids $i
#   else
#     echoerr "No import folder specified, so no files will be imported for node ${i}."
#   fi

# done
