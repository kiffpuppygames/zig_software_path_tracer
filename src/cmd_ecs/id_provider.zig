pub const IdProvider = struct {    
    next_id: u64 = 0,
    pub fn init() IdProvider {
        return IdProvider{ };
    }
    pub fn get_id(self: *IdProvider) u64 {
        defer self.next_id += 1;
        return self.next_id;
    }
};