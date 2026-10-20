interface AvatarProps {
  username: string
  /** 头像 URL，空串时回退为 teal 底首字母色块 */
  avatar: string
  className?: string
}

/** 用户头像：有图用图，无图用 teal 底首字母色块（概况页/用户页共用） */
export function Avatar({ username, avatar, className = 'h-8 w-8' }: AvatarProps) {
  if (avatar) {
    return (
      <img
        src={avatar}
        alt={`${username} 的头像`}
        className={`${className} shrink-0 rounded-full border border-track object-cover`}
      />
    )
  }
  return (
    <span
      aria-hidden
      className={`${className} flex shrink-0 select-none items-center justify-center rounded-full bg-accent text-xs font-bold text-white`}
    >
      {username.charAt(0).toUpperCase()}
    </span>
  )
}
