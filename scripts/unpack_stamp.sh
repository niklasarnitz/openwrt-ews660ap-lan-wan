#!/bin/sh

arc="$1"
dir=$(echo $(cd "$2"; pwd))

#untar
case "$arc" in
	*"tar.xz") xzcat "$arc" | tar -xf - -C "$dir" ;;
esac

#touch
case "$arc" in
	*"tar.xz") \
		xzcat "$arc" | tar -tf - | grep .prepared* | xargs -I {} touch "$dir/{}" 2>/dev/null;
		xzcat "$arc" | tar -tf - | grep .configured | xargs -I {} touch "$dir/{}" 2>/dev/null;
		xzcat "$arc" | tar -tf - | grep .built | xargs -I {} touch "$dir/{}" 2>/dev/null;
		xzcat "$arc" | tar -tf - | grep .installed | xargs -I {} touch "$dir/{}" 2>/dev/null;
		xzcat "$arc" | tar -tf - | grep .autoremove | xargs -I {} touch "$dir/{}" 2>/dev/null;
		;;
esac
