local id = {}
id.cnt = 0
function id:get()
    self.cnt = self.cnt + 1
    return self.cnt
end
return id
