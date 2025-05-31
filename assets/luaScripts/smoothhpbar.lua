settings = {
    DenpaMiss = true,
    FlipBar = false,
    VerticalBar = false
}
 
local health = 1
local percent = 1
local HPSmooth = 1
function onUpdatePost(elapsed)
    if settings.DenpaMiss then
        if flinch == true then
            setProperty('iconP1.animation.curAnim.curFrame', 1)
        end
    end
 
    if getProperty('health') < 2 then
        health = math.lerp(health, getProperty('health'), math.boundTo(elapsed * 20, 0, 1))
    else
        health = 2
    end
 
    setProperty('healthBar.numDivisions', 10000)
 
    HPSmooth = math.lerp(HPSmooth, getProperty('health') * 50, elapsed * 20)
 
    setProperty('healthBar.percent', HPSmooth)
 
    if settings.FlipBar then
        percent = health/2
        setProperty('iconP1.x', -105 + getProperty('healthBar.x') + (getProperty('healthBar.width') * percent) + (150 * getProperty('iconP1.scale.x') - 150) / 2 - 26)
        setProperty('iconP2.x', 105 + getProperty('healthBar.x') + (getProperty('healthBar.width') * percent) - (150 * getProperty('iconP2.scale.x')) / 2 - 26 * 2)
        setProperty('iconP1.flipX', true)
        setProperty('iconP2.flipX', true)
        setProperty('healthBar.flipX', true)
        setProperty('healthBar.angle', 0)
    else
        percent = 1-(health/2)
        setProperty('iconP1.x', getProperty('healthBar.x') + (getProperty('healthBar.width') * percent) + (150 * getProperty('iconP1.scale.x') - 150) / 2 - 26)
        setProperty('iconP2.x', getProperty('healthBar.x') + (getProperty('healthBar.width') * percent) - (150 * getProperty('iconP2.scale.x')) / 2 - 26 * 2)
        setProperty('iconP1.flipX', false)
        setProperty('iconP2.flipX', false)
        setProperty('healthBar.flipX', false)
        setProperty('healthBar.angle', 0)
    end
 
    if settings.VerticalBar then
        setProperty('healthBar.angle', 90)
        setProperty('healthBar.x', -220)
        setProperty('healthBar.y', 360)
 
        setProperty('iconP1.flipX', false)
        setProperty('iconP2.flipX', false)
 
        setProperty('iconP2.x', getProperty('healthBar.x') + 220)
        setProperty('iconP1.x', getProperty('healthBar.x') + 220)
 
        if settings.FlipBar then
            setProperty('healthBar.flipX', true)
 
            setProperty('iconP2.y', 395 + getProperty('healthBar.x') + (getProperty('healthBar.width') * percent) - (150 * getProperty('iconP2.scale.x')) / 2 - 26 * 2)
 
            setProperty('iconP1.y', 205 + getProperty('healthBar.x') + (getProperty('healthBar.width') * percent) + (150 * getProperty('iconP1.scale.x') - 150) / 2 - 26)
        else
            setProperty('healthBar.flipX', false)
 
            setProperty('iconP2.y', 305 + getProperty('healthBar.x') + (getProperty('healthBar.width') * percent) - (150 * getProperty('iconP2.scale.x')) / 2 - 26 * 2)
 
            setProperty('iconP1.y', 295 + getProperty('healthBar.x') + (getProperty('healthBar.width') * percent) + (150 * getProperty('iconP1.scale.x') - 150) / 2 - 26)
        end
    end
 
    if not settings.VerticalBar and not settings.FlipBar then
        setProperty('iconP1.x', getProperty('healthBar.x') + (getProperty('healthBar.width') * percent) + (150 * getProperty('iconP1.scale.x') - 150) / 2 - 26)
        setProperty('iconP2.x', getProperty('healthBar.x') + (getProperty('healthBar.width') * percent) - (150 * getProperty('iconP2.scale.x')) / 2 - 26 * 2)
        setProperty('iconP1.flipX', false)
        setProperty('iconP2.flipX', false)
        setProperty('healthBar.flipX', false)
        setProperty('healthBar.angle', 0)
    end
end
 
function noteMissPress()
    if settings.DenpaMiss then
        flinch = true
        runTimer('flinch', 0.5)
    end
end
 
function noteMiss()
    if settings.DenpaMiss then
        flinch = true
        runTimer('flinch', 0.5)
    end
end
 
function onTimerCompleted(tag)
    if tag == 'flinch' then
        flinch = false
    end
end
 
function rgbToHex(array)
    return string.format('%.2x%.2x%.2x', array[1], array[2], array[3])
end
 
function math.lerp(a, b, ratio) 
    return a + ratio * (b - a) 
end
 
function math.boundTo(value,min,max)
    local newValue = value
    if newValue < min then
        newValue = min
    elseif newValue > max then
        newValue = max
    end
    return newValue
end